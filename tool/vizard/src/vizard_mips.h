#ifndef VIZARD_MIPS_H
#define VIZARD_MIPS_H

#include "mmio_intr_cop0.h"
#include VIZARD_SHARED_HEADER
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* Minimal MIPS-I interpreter that runs the app's ISR image (isrN.s). */

#define VIZARD_MIPS_ROM_BASE   0xC0000000u
#define VIZARD_MIPS_ROM_BYTES  0x4000u
#define VIZARD_MIPS_ISR_VECTOR 0xC0000180u
#define VIZARD_MIPS_RETURN     0xFFFFFFF0u
#define VIZARD_MIPS_SM_BASE    SM_BASE_ADDRESS
#define VIZARD_MIPS_SM_BYTES   0x200u
#define VIZARD_MIPS_MMIO_BASE  MMIO_BASE
#define VIZARD_MIPS_MMIO_BYTES 0x100u
#define VIZARD_MIPS_MAX_STEPS  100000u

typedef struct {
    uint32_t (*read)(void *ctx, uint32_t address);
    void (*write)(void *ctx, uint32_t address, uint32_t value);
    void *ctx;
} VizardMipsMmio;

typedef struct {
    uint32_t reg[32];
    uint32_t pc, npc;
    uint32_t status, cause, epc, compare, count;
    bool faulted;
    uint8_t rom[VIZARD_MIPS_ROM_BYTES];
    size_t rom_bytes;
    uint8_t sm[VIZARD_MIPS_SM_BYTES];
    struct {
        uint32_t offset;
        volatile uint32_t *word;
    } shared[4];
    VizardMipsMmio mmio;
} VizardMips;

void vizard_mips_init(VizardMips *cpu, VizardMipsMmio mmio);
bool vizard_mips_load(VizardMips *cpu, const char *path);
/* Point the SM words the host owns (seconds, clock, ...) at host variables. */
void vizard_mips_map_shared(VizardMips *cpu, volatile uint32_t *seconds,
                            volatile uint32_t *clock, volatile uint32_t *rtc_count,
                            volatile uint32_t *flags);
/* Raise Cause bits and run the ISR to completion; false on fault. */
bool vizard_mips_interrupt(VizardMips *cpu, uint32_t cause_bits);

#endif
