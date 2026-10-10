#include "vizard.h"

#include <assert.h>
#include <stdio.h>

void vizard_host_uart_write(unsigned char byte)
{
    (void)byte;
}

int vizard_host_uart_read(void)
{
    return -1;
}

static uint32_t pixel(const VizardGpu *gpu, unsigned frame, unsigned x, unsigned y)
{
    const uint32_t *pixels = vizard_gpu_frame(gpu, frame);
    assert(pixels != NULL);
    return pixels[y * gpu->width + x];
}

static void test_gpu_commands(void)
{
    VizardGpu gpu;
    assert(vizard_gpu_init(&gpu, 16, 16));

    const uint32_t commands[] = {
        0x10ff0000u,
        0x2f00ff00u, 0x00010001u, 0x00030003u,
        0x3f0000ffu, 0x00080008u, 0x00020002u, 0xff303030u,
        0x4fffff00u, 0x000b000bu, 0x000e000eu, 0xff101010u,
        0x00000000u
    };
    assert(vizard_gpu_submit(&gpu, commands, sizeof(commands) / sizeof(commands[0]), 0x10400000u));
    assert(gpu.frame == 1);
    assert(!gpu.fault);
    assert(pixel(&gpu, 1, 0, 0) == 0xffff0000u);
    assert(pixel(&gpu, 1, 2, 2) == 0xff00ff00u);
    assert(pixel(&gpu, 1, 10, 8) == 0xff0000ffu);
    assert(pixel(&gpu, 1, 8, 8) == 0xff303030u);
    assert(pixel(&gpu, 1, 11, 11) == 0xffffff00u);
    assert(pixel(&gpu, 1, 12, 12) == 0xff101010u);

    const uint32_t bad_stop[] = { 0x00000001u };
    assert(!vizard_gpu_submit(&gpu, bad_stop, 1, 1));
    assert(gpu.fault);

    const uint32_t truncated[] = { 0x20000000u, 0x00000000u };
    assert(!vizard_gpu_submit(&gpu, truncated, 2, 1));
    assert(gpu.fault);

    const uint32_t missing_stop[] = { 0x10000000u };
    assert(!vizard_gpu_submit(&gpu, missing_stop, 1, 1));
    assert(gpu.fault);
    vizard_gpu_dispose(&gpu);
}

static void test_pixel_command(void)
{
    VizardGpu gpu;
    assert(vizard_gpu_init(&gpu, 16, 16));

    const uint32_t commands[] = {
        0x20a1b2c3u, 0x00070009u, 0x00070009u, 0
    };
    assert(vizard_gpu_submit(&gpu, commands,
                             sizeof(commands) / sizeof(commands[0]), 0));
    assert(pixel(&gpu, 0, 7, 9) == 0xffa1b2c3u);
    assert(pixel(&gpu, 0, 6, 9) == 0);
    assert(pixel(&gpu, 0, 8, 9) == 0);
    assert(pixel(&gpu, 0, 7, 8) == 0);
    assert(pixel(&gpu, 0, 7, 10) == 0);

    vizard_gpu_dispose(&gpu);
}

static void test_gpu_stream_word_count(void)
{
    const uint32_t commands[] = {
        0x10002233u,
        0x2f00ffffu, 0x000a000au, 0x02bc012cu,
        0x2f00ffffu, 0x0190000au, 0x000a01f4u,
        0x2f00ffffu, 0x001400fau, 0x001400fau,
        0x4f00ffffu, 0x02260096u, 0x02ee00fau, 0xfff0f020u,
        0x00000000u
    };
    size_t word_count = 0;
    assert(vizard_gpu_stream_word_count(
        commands, sizeof(commands) / sizeof(commands[0]), &word_count));
    assert(word_count == sizeof(commands) / sizeof(commands[0]));

    const uint32_t truncated[] = { 0x20000000u, 0x00000000u };
    assert(!vizard_gpu_stream_word_count(
        truncated, sizeof(truncated) / sizeof(truncated[0]), &word_count));
}

static void test_ellipse_border_thickness(void)
{
    VizardGpu gpu;
    assert(vizard_gpu_init(&gpu, 64, 64));

    const uint32_t commands[] = {
        0x30ff0000u, 0x00200020u, 0x0014000fu, 0xff0000ffu, 0
    };
    assert(vizard_gpu_submit(&gpu, commands,
                             sizeof(commands) / sizeof(commands[0]), 0));

    unsigned edge_pixels = 0;
    for (unsigned x = 0; x < gpu.width; ++x) {
        if (pixel(&gpu, 0, x, 32) == 0xffff0000u) {
            ++edge_pixels;
        }
    }
    assert(edge_pixels == 2);
    assert(pixel(&gpu, 0, 12, 32) == 0xffff0000u);
    assert(pixel(&gpu, 0, 13, 32) == 0xff0000ffu);
    assert(pixel(&gpu, 0, 52, 32) == 0xffff0000u);
    assert(pixel(&gpu, 0, 51, 32) == 0xff0000ffu);

    vizard_gpu_dispose(&gpu);
}

static void test_uart_registers(void)
{
    VizardUart uart;
    uint8_t byte;
    vizard_uart_init(&uart);

    assert(vizard_uart_read32(&uart, VIZARD_UART_TX_READY) == 1);
    vizard_uart_write32(&uart, VIZARD_UART_TX_DATA, 'O');
    vizard_uart_write32(&uart, VIZARD_UART_TX_DATA, 'K');
    assert(vizard_uart_transmit(&uart, &byte) && byte == 'O');
    assert(vizard_uart_transmit(&uart, &byte) && byte == 'K');
    assert(!vizard_uart_transmit(&uart, &byte));

    assert(vizard_uart_receive(&uart, 'R'));
    assert(vizard_uart_read32(&uart, VIZARD_UART_RX_VALID) == 1);
    assert(vizard_uart_read32(&uart, VIZARD_UART_RX_DATA) == 'R');
    assert(vizard_uart_read32(&uart, VIZARD_UART_RX_VALID) == 0);
}

int main(void)
{
    test_gpu_commands();
    test_pixel_command();
    test_gpu_stream_word_count();
    test_ellipse_border_thickness();
    test_uart_registers();
    puts("Vizard core tests passed.");
    return 0;
}