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
    test_uart_registers();
    puts("Vizard core tests passed.");
    return 0;
}