#include "vizard_mips.h"

#include <assert.h>
#include <stdio.h>

static uint32_t rx_byte = ' ';

static uint32_t mmio_read(void *ctx, uint32_t address)
{
    (void)ctx;
    if (address == 0x80000004u) return 1;
    if (address == 0x8000000cu) return rx_byte;
    return 0;
}

int main(void)
{
    VizardMips cpu;
    uint32_t seconds = 5, clock = 0x0059, rtc = 0, flags = 0;
    vizard_mips_init(&cpu, (VizardMipsMmio){ mmio_read, NULL, NULL });
    assert(vizard_mips_load(&cpu, VIZARD_ISR_IMAGE));
    vizard_mips_map_shared(&cpu, &seconds, &clock, &rtc, &flags);

    cpu.status = IM_GLOBAL | IM_TIMER | IM_UARX;
    cpu.compare = 50000000u;
    assert(vizard_mips_interrupt(&cpu, IM_TIMER));
    assert(seconds == 6);
    assert(clock == 0x0100);
    assert(cpu.compare == 100000000u);
    assert((cpu.cause & IM_TIMER) == 0);
    assert(cpu.status & IM_GLOBAL);

    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(flags == 1);
    rx_byte = 'd';
    assert(vizard_mips_interrupt(&cpu, IM_UARX));
    assert(flags == 3);

    puts("Vizard MIPS ISR tests passed.");
    return 0;
}
