#include "vizard_mips.h"
#include "vizard_host.h"
#include "vizard_gpu.h"
#include "vizard_uart.h"

#include "raylib.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define PANEL_WIDTH 280
#define WINDOW_WIDTH (VIZARD_SCREEN_WIDTH + PANEL_WIDTH)
#define WINDOW_HEIGHT VIZARD_SCREEN_HEIGHT
static VizardGpu gpu;
static VizardUart uart;
static VizardMips cpu;
static Texture2D canvas;
static Color *upload_pixels;
static bool compare_armed;
static double next_timer;
static double next_draw;
static unsigned int rx_total;
static int last_key;
static volatile bool host_error;
static pthread_mutex_t gpu_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_t gpu_thread;
static bool gpu_thread_started;
static volatile bool gpu_thread_stop;
static volatile struct SM_DATA *active_shared_data;
static volatile struct SM_DATA idle_shared_data;
static volatile void *pending_pf_frame;
static bool pf_frame_pending;

volatile void * volatile vizard_pf_frame = (volatile void *)0x10400000u;
volatile void * volatile vizard_gp_frame = (volatile void *)0x10400000u;
void * volatile vizard_gp_gcode;
volatile unsigned int vizard_gp_state_storage = 0xf8000000u;

static unsigned int frame_number(volatile void *frame)
{
    unsigned int address = (unsigned int)(uintptr_t)frame;
    return (address >> 28) ? ((address >> 22) & 0x3fu) : (address & 0x3fu);
}

static unsigned int frame_address(unsigned int frame)
{
    return 0x10000000u | ((frame_number((volatile void *)(uintptr_t)frame) & 0x3fu) << 22);
}

static uint32_t cpu_mmio_read(void *ctx, uint32_t address)
{
    (void)ctx;
    return vizard_uart_read32(&uart, address);
}

static void cpu_mmio_write(void *ctx, uint32_t address, uint32_t value)
{
    (void)ctx;
    if (address == VIZARD_UART_TX_DATA) {
        vizard_host_uart_write((unsigned char)value);
    } else {
        vizard_host_report_error("write to an unsupported MMIO register");
    }
}

static void draw_host_view(unsigned int seconds, unsigned int clock)
{
    unsigned int display_frame = frame_number(vizard_pf_frame);
    if (display_frame >= VIZARD_FRAME_COUNT) {
        vizard_host_report_error("pixel feeder selected an unsupported frame");
        return;
    }
    pthread_mutex_lock(&gpu_lock);
    const uint32_t *pixels = vizard_gpu_frame(&gpu, display_frame);
    size_t pixel_count = (size_t)VIZARD_SCREEN_WIDTH * VIZARD_SCREEN_HEIGHT;
    if (pixels == NULL) {
        for (size_t i = 0; i < pixel_count; ++i) {
            upload_pixels[i] = (Color){ 9, 13, 17, 255 };
        }
    } else {
        for (size_t i = 0; i < pixel_count; ++i) {
            upload_pixels[i] = (Color){
                (unsigned char)(pixels[i] >> 16),
                (unsigned char)(pixels[i] >> 8),
                (unsigned char)pixels[i],
                (unsigned char)(pixels[i] >> 24)
            };
        }
    }
    bool gpu_fault = gpu.fault;
    size_t gpu_commands = gpu.commands_processed;
    pthread_mutex_unlock(&gpu_lock);
    UpdateTexture(canvas, upload_pixels);

    BeginDrawing();
    ClearBackground((Color){ 18, 23, 29, 255 });
    DrawTexture(canvas, 0, 0, WHITE);
    if (pixels == NULL) {
        DrawText("projN.c has no GPU commands", 34, 280, 22, (Color){ 171, 185, 187, 255 });
    }
    DrawRectangle(VIZARD_SCREEN_WIDTH, 0, PANEL_WIDTH, WINDOW_HEIGHT,
                  (Color){ 27, 34, 40, 255 });
    DrawText("VIZARD", VIZARD_SCREEN_WIDTH + 20, 22, 26, RAYWHITE);
    DrawText("software/proj_appN/projN.c", VIZARD_SCREEN_WIDTH + 20, 56, 12,
             (Color){ 116, 196, 184, 255 });
    DrawLine(VIZARD_SCREEN_WIDTH + 20, 82, WINDOW_WIDTH - 20, 82,
             (Color){ 67, 82, 89, 255 });

    char status[96];
    snprintf(status, sizeof(status), "AppN  %s", gpu_fault ? "GPU FAULT" : "RUNNING");
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 104, 16,
             gpu_fault ? RED : (Color){ 145, 218, 157, 255 });
    snprintf(status, sizeof(status), "Clock: %02X:%02X",
             (clock >> 8) & 0xffu, clock & 0xffu);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 142, 20, RAYWHITE);
    snprintf(status, sizeof(status), "Timer seconds: %u", seconds);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 172, 14, LIGHTGRAY);
    snprintf(status, sizeof(status), "GPU frame: %u   commands: %zu",
             display_frame, gpu_commands);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 198, 12, LIGHTGRAY);

    DrawLine(VIZARD_SCREEN_WIDTH + 20, 238, WINDOW_WIDTH - 20, 238,
             (Color){ 67, 82, 89, 255 });
    DrawText("UART RX", VIZARD_SCREEN_WIDTH + 20, 256, 14,
             (Color){ 116, 196, 184, 255 });
    DrawText("Key presses enter the RX FIFO", VIZARD_SCREEN_WIDTH + 20, 280, 12, LIGHTGRAY);
    snprintf(status, sizeof(status), "Received: %u   queued: %u", rx_total,
             (unsigned int)uart.rx_count);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 303, 12, RAYWHITE);
    if (last_key > 0) {
        snprintf(status, sizeof(status), "Last key: %c", last_key);
        DrawText(status, VIZARD_SCREEN_WIDTH + 20, 325, 14, RAYWHITE);
    }
    DrawText("Escape closes Vizard", VIZARD_SCREEN_WIDTH + 20, 552, 12, LIGHTGRAY);
    DrawFPS(WINDOW_WIDTH - 68, WINDOW_HEIGHT - 26);
    EndDrawing();
}

/* Asynchronous GPU: consumes the stream the CPU publishes via GP_GCODE, then clears it. */
static void *gpu_thread_main(void *arg)
{
    (void)arg;
    while (!gpu_thread_stop) {
        const unsigned int *words = vizard_gp_gcode;
        if (words == NULL) {
            nanosleep(&(struct timespec){ 0, 100000 }, NULL);
            continue;
        }
        size_t word_count;
        if (!vizard_gpu_stream_word_count(words, VIZARD_GPU_COMMAND_CAPACITY, &word_count)) {
            fprintf(stderr, "Vizard: malformed or unterminated GP_GCODE stream "
                            "(limit %u words)\n", VIZARD_GPU_COMMAND_CAPACITY);
            pthread_mutex_lock(&gpu_lock);
            gpu.fault = true;
            pthread_mutex_unlock(&gpu_lock);
            vizard_host_report_error("malformed or unterminated GP_GCODE stream");
        } else {
            static size_t largest_warned;
            if (word_count > VIZARD_GPU_STREAM_WARN_WORDS && word_count > largest_warned) {
                largest_warned = word_count;
                fprintf(stderr, "Vizard: GP stream is %zu words (> %u-word warning threshold); FPGA limits are not modeled\n",
                        word_count, VIZARD_GPU_STREAM_WARN_WORDS);
            }
            vizard_host_gpu_submit(words, word_count, frame_number(vizard_gp_frame));
        }
        vizard_gp_gcode = NULL;
    }
    return NULL;
}

bool vizard_host_init(void)
{
    SetTraceLogLevel(RAYLIB_LOG_LEVEL); // Passed from Makefile
    host_error = false;
    if (!vizard_gpu_init(&gpu, VIZARD_SCREEN_WIDTH, VIZARD_SCREEN_HEIGHT)) {
        vizard_host_report_error("unable to initialize the software GPU");
        return false;
    }
    vizard_uart_init(&uart);
    vizard_mips_init(&cpu, (VizardMipsMmio){ cpu_mmio_read, cpu_mmio_write, NULL });
    if (!vizard_mips_load(&cpu, VIZARD_ISR_IMAGE)) { // Passed from Makefile
        char message[256];
        snprintf(message, sizeof(message), "unable to load ISR image %s", VIZARD_ISR_IMAGE);
        vizard_host_report_error(message);
        vizard_gpu_dispose(&gpu);
        return false;
    }
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Vizard | MIPS150 app host");
    if (!IsWindowReady()) {
        vizard_host_report_error("Raylib failed to create the preview window");
        vizard_gpu_dispose(&gpu);
        return false;
    }
    SetTargetFPS(60); // Set RayLib framerate to match current DVI output from hardware

    Image image = GenImageColor(VIZARD_SCREEN_WIDTH, VIZARD_SCREEN_HEIGHT, BLACK);
    if (!IsImageValid(image)) {
        vizard_host_report_error("unable to allocate the preview image");
        UnloadImage(image);
        CloseWindow();
        vizard_gpu_dispose(&gpu);
        return false;
    }
    canvas = LoadTextureFromImage(image);
    UnloadImage(image);
    if (!IsTextureValid(canvas)) {
        vizard_host_report_error("unable to create the preview texture");
        CloseWindow();
        vizard_gpu_dispose(&gpu);
        return false;
    }
    upload_pixels = malloc((size_t)VIZARD_SCREEN_WIDTH * VIZARD_SCREEN_HEIGHT * sizeof(Color));
    if (upload_pixels == NULL) {
        vizard_host_report_error("unable to allocate the preview pixel buffer");
        UnloadTexture(canvas);
        CloseWindow();
        vizard_gpu_dispose(&gpu);
        return false;
    }
    gpu_thread_stop = false;
    if (pthread_create(&gpu_thread, NULL, gpu_thread_main, NULL) != 0) {
        vizard_host_report_error("unable to start the GPU thread");
        free(upload_pixels);
        upload_pixels = NULL;
        UnloadTexture(canvas);
        CloseWindow();
        vizard_gpu_dispose(&gpu);
        return false;
    }
    gpu_thread_started = true;
    next_draw = GetTime();
    return true;
}

void vizard_host_report_error(const char *message)
{
    if (!host_error) {
        fprintf(stderr, "Vizard error: %s\n", message != NULL ? message : "unspecified failure");
    }
    host_error = true;
}

bool vizard_host_failed(void)
{
    return host_error;
}

void vizard_host_shutdown(void)
{
    if (gpu_thread_started) {
        gpu_thread_stop = true;
        pthread_join(gpu_thread, NULL);
        gpu_thread_started = false;
    }
    free(upload_pixels);
    upload_pixels = NULL;
    UnloadTexture(canvas);
    CloseWindow();
    vizard_gpu_dispose(&gpu);
}

void vizard_host_isr_status(unsigned int keep, unsigned int set)
{
    unsigned int previous = cpu.status;
    cpu.status = (cpu.status & keep) | set;
    unsigned int timer_mask = IM_GLOBAL | IM_TIMER;
    if ((previous & timer_mask) != timer_mask &&
        (cpu.status & timer_mask) == timer_mask && compare_armed) {
        next_timer = GetTime() + 1.0;
    }
}

void vizard_host_isr_compare(unsigned int compare)
{
    cpu.compare = compare;
    cpu.count = 0;
    compare_armed = true;
    next_timer = GetTime() + 1.0;
}

static bool service_uart_rx(void)
{
    unsigned int enabled = IM_GLOBAL | IM_UARX;
    while ((cpu.status & enabled) == enabled &&
           vizard_uart_read32(&uart, VIZARD_UART_RX_VALID) != 0) {
        if (!vizard_mips_interrupt(&cpu, IM_UARX)) {
            vizard_host_report_error("MIPS ISR failed while servicing UART receive");
            return false;
        }
    }
    return true;
}

bool vizard_host_poll(volatile struct SM_DATA *shared_data)
{
    if (host_error) {
        return false;
    }
    if (shared_data == NULL) {
        vizard_host_report_error("poll received a null shared-data pointer");
        return false;
    }
    active_shared_data = shared_data;
    vizard_mips_map_shared(&cpu, shared_data);
    if (WindowShouldClose()) {
        return false;
    }

    int character = GetCharPressed();
    while (character > 0) {
        if (((character >= 32 && character <= 255) || character == '\r' || character == '\n') &&
            !vizard_uart_receive(&uart, (uint8_t)character)) {
            vizard_host_report_error("UART RX FIFO is full; input was lost");
            return false;
        } else if ((character >= 32 && character <= 255) || character == '\r' || character == '\n') {
            last_key = character;
            ++rx_total;
        }
        character = GetCharPressed();
    }
    if (!service_uart_rx()) {
        return false;
    }
    if (host_error) {
        return false;
    }

    double now = GetTime();
    unsigned int timer_mask = IM_GLOBAL | IM_TIMER;
    while (compare_armed && now >= next_timer && (cpu.status & timer_mask) == timer_mask) {
        next_timer += 1.0;
        if (!vizard_mips_interrupt(&cpu, IM_TIMER)) {
            vizard_host_report_error("MIPS ISR failed while servicing timer interrupt");
            return false;
        }
    }
    if (host_error) {
        return false;
    }
    if (now >= next_draw) {
        if (pf_frame_pending) {
            vizard_pf_frame = pending_pf_frame;
            pf_frame_pending = false;
        }
        draw_host_view(shared_data->seconds, shared_data->clock);
        if (host_error) {
            return false;
        }
        next_draw = now + (1.0 / 60.0);
    }
    WaitTime(0.001);
    return true;
}

bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame)
{
    pthread_mutex_lock(&gpu_lock);
    bool success = vizard_gpu_submit(&gpu, words, word_count, frame);
    vizard_gp_state_storage = 0xf8000000u |
                              ((gpu.frame & 0x3fu) << 18) |
                              (gpu.fault ? (1u << 16) : 0u);
    unsigned int failed_frame = gpu.frame;
    pthread_mutex_unlock(&gpu_lock);
    if (!success) {
        char message[96];
        snprintf(message, sizeof(message), "GPU command stream failed on frame %u", failed_frame);
        vizard_host_report_error(message);
    }
    return success;
}

void vizard_host_wait_gpu(void)
{
    volatile struct SM_DATA *shared_data = active_shared_data != NULL ?
                                           active_shared_data : &idle_shared_data;
    while (vizard_gp_gcode != NULL) {
        if (!vizard_host_poll(shared_data)) {
            break;
        }
    }
}

void vizard_host_wait_pf_frame(unsigned int frame)
{
    if (frame_number((volatile void *)(uintptr_t)frame) >= VIZARD_FRAME_COUNT) {
        vizard_host_report_error("requested pixel-feeder frame is unsupported");
        return;
    }
    unsigned int target = frame_address(frame);
    if (frame_number(vizard_pf_frame) == frame_number((volatile void *)(uintptr_t)target)) {
        return;
    }

    pending_pf_frame = (volatile void *)(uintptr_t)target;
    pf_frame_pending = true;

    volatile struct SM_DATA *shared_data = active_shared_data != NULL ?
                                           active_shared_data : &idle_shared_data;
    while (frame_number(vizard_pf_frame) != frame_number((volatile void *)(uintptr_t)target)) {
        if (!vizard_host_poll(shared_data)) {
            break;
        }
    }
}

void vizard_host_uart_write(unsigned char byte)
{
    fputc(byte, stdout);
    fflush(stdout);
}

int vizard_host_uart_read(void)
{
    while (vizard_uart_read32(&uart, VIZARD_UART_RX_VALID) == 0) {
        volatile struct SM_DATA *shared_data = active_shared_data != NULL ?
                               active_shared_data : &idle_shared_data;
        if (!vizard_host_poll(shared_data)) {
            return -1;
        }
    }
    return (int)vizard_uart_read32(&uart, VIZARD_UART_RX_DATA);
}

void uwrite_int8s_ISR_VIZARD(const char *src)
{
    fputs(src, stdout);
    fflush(stdout);
}

void uwait_ISR_VIZARD(void)
{
    fflush(stdout);
}