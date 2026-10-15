#include "vizard_mips.h"

#include <assert.h>
#include <stdio.h>

static uint32_t rx_byte = ' ';
static uint32_t tx_byte;

static uint32_t mmio_read(void *ctx, uint32_t address)
{
    (void)ctx;
    if (address == MM_UARX_VALID) return 1;
    if (address == MM_UARX_DATA) return rx_byte;
    return 0;
}

static void mmio_write(void *ctx, uint32_t address, uint32_t value)
{
    (void)ctx;
    if (address == MM_UATX_DATA) tx_byte = value;
}

int main(void)
{
    VizardMips cpu;
    struct SM_DATA shared = {0};
    shared.seconds = 5;
    shared.clock = 0x0059;
    shared.player_y = 300;
    shared.player_x = 400;
    shared.buff_head = 1;
    shared.buff_data[0] = 'X';
    vizard_mips_init(&cpu, (VizardMipsMmio){ mmio_read, mmio_write, NULL });
    assert(vizard_mips_load(&cpu, VIZARD_ISR_IMAGE));
    vizard_mips_map_shared(&cpu, &shared);

    cpu.status = IM_GLOBAL | IM_TIMER | IM_UARX;
    cpu.compare = 50000000u;
    assert(vizard_mips_interrupt(&cpu, IM_TIMER));
    assert(shared.seconds == 6);
    assert(shared.clock == 0x0100);
    assert(cpu.compare == 100000000u);
    assert((cpu.cause & IM_TIMER) == 0);
    assert(cpu.status & IM_GLOBAL);

    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.flags == 1);
    rx_byte = 'd';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.flags == 3);
    rx_byte = 'e';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.flags == 1);
    rx_byte = 'i';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.player_y == 299);
    rx_byte = 'm';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.player_y == 300);
    rx_byte = 'j';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.player_x == 399);
    rx_byte = 'l';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(shared.player_x == 400);

    cpu.status |= IM_UATX;
    assert(vizard_mips_interrupt(&cpu, IM_UATX));
    assert(shared.buff_tail == 1);
    assert(tx_byte == 'X');

    puts("Vizard MIPS ISR tests passed.");
    return 0;
}
