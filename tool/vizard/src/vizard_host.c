#include "vizard.h"
#include "vizard_host.h"

#include "raylib.h"

#include <stdio.h>
#include <stdlib.h>

#define PANEL_WIDTH 280
#define WINDOW_WIDTH (VIZARD_SCREEN_WIDTH + PANEL_WIDTH)
#define WINDOW_HEIGHT VIZARD_SCREEN_HEIGHT
#define IM_GLOBAL (1u << 0)
#define IM_TIMER (1u << 15)

static VizardGpu gpu;
static VizardUart uart;
static Texture2D canvas;
static Color *upload_pixels;
static unsigned int interrupt_status;
static bool compare_armed;
static double next_timer;
static double next_draw;
static unsigned int rx_total;
static int last_key;
static volatile unsigned int *active_seconds;
static volatile unsigned int *active_clock;
static volatile unsigned int *active_rtc_count;
static volatile unsigned int idle_seconds;
static volatile unsigned int idle_clock;
static volatile unsigned int idle_rtc_count;

volatile void * volatile vizard_pf_frame = (volatile void *)0x10400000u;
volatile void * volatile vizard_gp_frame = (volatile void *)0x10400000u;
void * volatile vizard_gp_gcode;
volatile unsigned int vizard_gp_state_storage = 0xf8000000u;

static unsigned int frame_number(volatile void *frame)
{
    unsigned int address = (unsigned int)(unsigned long)frame;
    return (address >> 28) ? ((address >> 22) & 0x3fu) : (address & 0x3fu);
}

static unsigned int increment_bcd_clock(unsigned int clock)
{
    static const unsigned int maximum[] = { 9, 5, 9, 5 };
    for (unsigned int digit = 0; digit < 4; ++digit) {
        unsigned int shift = digit * 4;
        unsigned int value = (clock >> shift) & 0xfu;
        clock &= ~(0xfu << shift);
        if (value < maximum[digit]) {
            return clock | ((value + 1u) << shift);
        }
    }
    return clock;
}

static void draw_host_view(unsigned int seconds, unsigned int clock)
{
    unsigned int display_frame = frame_number(vizard_pf_frame);
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
    UpdateTexture(canvas, upload_pixels);

    BeginDrawing();
    ClearBackground((Color){ 18, 23, 29, 255 });
    DrawTexture(canvas, 0, 0, WHITE);
    if (pixels == NULL) {
        DrawText("proj5.c has no GPU commands", 34, 280, 22, (Color){ 171, 185, 187, 255 });
    }
    DrawRectangle(VIZARD_SCREEN_WIDTH, 0, PANEL_WIDTH, WINDOW_HEIGHT,
                  (Color){ 27, 34, 40, 255 });
    DrawText("VIZARD", VIZARD_SCREEN_WIDTH + 20, 22, 26, RAYWHITE);
    DrawText("software/proj_app5/proj5.c", VIZARD_SCREEN_WIDTH + 20, 56, 12,
             (Color){ 116, 196, 184, 255 });
    DrawLine(VIZARD_SCREEN_WIDTH + 20, 82, WINDOW_WIDTH - 20, 82,
             (Color){ 67, 82, 89, 255 });

    char status[96];
    snprintf(status, sizeof(status), "APP5  %s", gpu.fault ? "GPU FAULT" : "RUNNING");
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 104, 16,
             gpu.fault ? RED : (Color){ 145, 218, 157, 255 });
    snprintf(status, sizeof(status), "Clock: %02X:%02X",
             (clock >> 8) & 0xffu, clock & 0xffu);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 142, 20, RAYWHITE);
    snprintf(status, sizeof(status), "Timer seconds: %u", seconds);
    DrawText(status, VIZARD_SCREEN_WIDTH + 20, 172, 14, LIGHTGRAY);
    snprintf(status, sizeof(status), "GPU frame: %u   commands: %zu",
             display_frame, gpu.commands_processed);
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

bool vizard_host_init(void)
{
    if (!vizard_gpu_init(&gpu, VIZARD_SCREEN_WIDTH, VIZARD_SCREEN_HEIGHT)) {
        return false;
    }
    vizard_uart_init(&uart);
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Vizard | MIPS150 app host");
    if (!IsWindowReady()) {
        vizard_gpu_dispose(&gpu);
        return false;
    }
    SetTargetFPS(60);

    Image image = GenImageColor(VIZARD_SCREEN_WIDTH, VIZARD_SCREEN_HEIGHT, BLACK);
    canvas = LoadTextureFromImage(image);
    UnloadImage(image);
    upload_pixels = malloc((size_t)VIZARD_SCREEN_WIDTH * VIZARD_SCREEN_HEIGHT * sizeof(Color));
    if (upload_pixels == NULL) {
        UnloadTexture(canvas);
        CloseWindow();
        vizard_gpu_dispose(&gpu);
        return false;
    }
    next_draw = GetTime();
    return true;
}

void vizard_host_shutdown(void)
{
    free(upload_pixels);
    upload_pixels = NULL;
    UnloadTexture(canvas);
    CloseWindow();
    vizard_gpu_dispose(&gpu);
}

void vizard_host_isr_status(unsigned int keep, unsigned int set)
{
    unsigned int previous = interrupt_status;
    interrupt_status = (interrupt_status & keep) | set;
    unsigned int timer_mask = IM_GLOBAL | IM_TIMER;
    if ((previous & timer_mask) != timer_mask &&
        (interrupt_status & timer_mask) == timer_mask && compare_armed) {
        next_timer = GetTime() + 1.0;
    }
}

void vizard_host_isr_compare(unsigned int compare)
{
    (void)compare;
    compare_armed = true;
    next_timer = GetTime() + 1.0;
}

bool vizard_host_poll(volatile unsigned int *seconds, volatile unsigned int *clock,
                      volatile unsigned int *rtc_count)
{
    active_seconds = seconds;
    active_clock = clock;
    active_rtc_count = rtc_count;
    if (WindowShouldClose()) {
        return false;
    }

    int character = GetCharPressed();
    while (character > 0) {
        if (((character >= 32 && character <= 255) || character == '\r' || character == '\n') &&
            vizard_uart_receive(&uart, (uint8_t)character)) {
            last_key = character;
            ++rx_total;
        }
        character = GetCharPressed();
    }

    if (vizard_gp_gcode != NULL) {
        const unsigned int *words = vizard_gp_gcode;
        const size_t max_words = 1u << 20;
        size_t word_count;
        for (word_count = 0; word_count < max_words; ++word_count) {
            if ((words[word_count] >> 28) == 0) {
                ++word_count;
                break;
            }
        }
        if (word_count == max_words) {
            fprintf(stderr, "Vizard: GP_GCODE stream has no STOP within %zu words\n", max_words);
            gpu.fault = true;
        } else {
            vizard_host_gpu_submit(words, word_count, frame_number(vizard_gp_frame));
        }
        vizard_gp_gcode = NULL;
    }

    double now = GetTime();
    if (compare_armed && (interrupt_status & (IM_GLOBAL | IM_TIMER)) == (IM_GLOBAL | IM_TIMER)) {
        while (now >= next_timer) {
            ++*seconds;
            *clock = increment_bcd_clock(*clock);
            next_timer += 1.0;
        }
    }
    if (now >= next_draw) {
        draw_host_view(*seconds, *clock);
        next_draw = now + (1.0 / 60.0);
    }
    WaitTime(0.001);
    return true;
}

bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame)
{
    bool success = vizard_gpu_submit(&gpu, words, word_count, frame);
    vizard_gp_state_storage = 0xf8000000u |
                              ((gpu.frame & 0x3fu) << 18) |
                              (gpu.fault ? (1u << 16) : 0u);
    if (!success) {
        fprintf(stderr, "Vizard: GPU command stream fault on frame %u\n", gpu.frame);
    }
    return success;
}

void vizard_host_wait_gpu(void)
{
    volatile unsigned int *seconds = active_seconds ? active_seconds : &idle_seconds;
    volatile unsigned int *clock = active_clock ? active_clock : &idle_clock;
    volatile unsigned int *rtc_count = active_rtc_count ? active_rtc_count : &idle_rtc_count;
    while (vizard_gp_gcode != NULL) {
        if (!vizard_host_poll(seconds, clock, rtc_count)) {
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
        volatile unsigned int *seconds = active_seconds ? active_seconds : &idle_seconds;
        volatile unsigned int *clock = active_clock ? active_clock : &idle_clock;
        volatile unsigned int *rtc_count = active_rtc_count ? active_rtc_count : &idle_rtc_count;
        if (!vizard_host_poll(seconds, clock, rtc_count)) {
            return -1;
        }
    }
    return (int)vizard_uart_read32(&uart, VIZARD_UART_RX_DATA);
}

void uwrite_int8s_ISR_VIZZARD(int8_t *src)
{
    fputs((const char *)src, stdout);
    fflush(stdout);
}

void uwait_ISR_VIZZARD(void)
{
    fflush(stdout);
}