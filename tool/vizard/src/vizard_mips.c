#include "vizard_mips.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void mips_contract_failure(const char *message)
{
    fprintf(stderr, "Vizard fatal: %s\n", message);
    abort();
}

void vizard_mips_init(VizardMips *cpu, VizardMipsMmio mmio)
{
    if (cpu == NULL) {
        mips_contract_failure("vizard_mips_init received a null CPU");
    }
    memset(cpu, 0, sizeof(*cpu));
    cpu->mmio = mmio;
}

bool vizard_mips_load(VizardMips *cpu, const char *path)
{
    if (cpu == NULL || path == NULL) {
        mips_contract_failure("vizard_mips_load received a null argument");
    }
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return false;
    }
    size_t count = fread(cpu->rom, 1, sizeof(cpu->rom), file);
    bool too_big = fgetc(file) != EOF;
    fclose(file);
    cpu->rom_bytes = count;
    return count > 0 && !too_big;
}

void vizard_mips_map_shared(VizardMips *cpu, volatile struct SM_DATA *shared_data)
{
    if (cpu == NULL || shared_data == NULL) {
        mips_contract_failure("vizard_mips_map_shared received a null argument");
    }
    cpu->shared_data = shared_data;
}

static volatile uint8_t *sm_ptr(VizardMips *cpu, uint32_t address, unsigned size)
{
    if (address < VIZARD_MIPS_SM_BASE) {
        return NULL;
    }
    uint32_t offset = address - VIZARD_MIPS_SM_BASE;
    if (offset > VIZARD_MIPS_SM_BYTES || size > VIZARD_MIPS_SM_BYTES - offset) {
        return NULL;
    }
    if (cpu->shared_data != NULL && offset <= sizeof(*cpu->shared_data) &&
        size <= sizeof(*cpu->shared_data) - offset) {
        return (volatile uint8_t *)cpu->shared_data + offset;
    }
    return cpu->sm + offset;
}

static bool is_mmio(uint32_t address)
{
    return address >= VIZARD_MIPS_MMIO_BASE &&
           address < VIZARD_MIPS_MMIO_BASE + VIZARD_MIPS_MMIO_BYTES;
}

static bool mem_read(VizardMips *cpu, uint32_t address, unsigned size, uint32_t *value)
{
    if (is_mmio(address)) {
        /* The hardware ignores the low bits, and isrN.s relies on that for byte offsets. */
        if (cpu->mmio.read == NULL) {
            return false;
        }
        *value = cpu->mmio.read(cpu->mmio.ctx, address & ~3u);
        return size == 1 || size == 4;
    }
    if (address & (size - 1)) {
        return false;
    }
    if (address >= VIZARD_MIPS_ROM_BASE &&
        address - VIZARD_MIPS_ROM_BASE + size <= cpu->rom_bytes) {
        uint32_t result = 0;
        for (unsigned i = 0; i < size; ++i) {
            result = (result << 8) | cpu->rom[address - VIZARD_MIPS_ROM_BASE + i];
        }
        *value = result;
        return true;
    }
    volatile uint8_t *p = sm_ptr(cpu, address, size);
    if (p == NULL) {
        return false;
    }
    *value = 0;
    for (unsigned i = 0; i < size; ++i) {
        *value |= (uint32_t)p[i] << (i * 8);
    }
    return true;
}

static bool mem_write(VizardMips *cpu, uint32_t address, unsigned size, uint32_t value)
{
    if (is_mmio(address)) {
        if (size != 4) {
            return false;
        }
        if (cpu->mmio.write == NULL) {
            return false;
        }
        cpu->mmio.write(cpu->mmio.ctx, address & ~3u, value);
        return true;
    }
    if (address & (size - 1)) {
        return false;
    }
    volatile uint8_t *p = sm_ptr(cpu, address, size);
    if (p == NULL) {
        return false;
    }
    for (unsigned i = 0; i < size; ++i) {
        p[i] = (uint8_t)(value >> (i * 8));
    }
    return true;
}

static uint32_t *cop0_reg(VizardMips *cpu, unsigned number)
{
    switch (number) {
    case 9:  return &cpu->count;
    case 11: return &cpu->compare;
    case 12: return &cpu->status;
    case 13: return &cpu->cause;
    case 14: return &cpu->epc;
    default: return NULL;
    }
}

static bool step(VizardMips *cpu, uint32_t *bad_instruction)
{
    uint32_t cur = cpu->pc;
    uint32_t in;
    if (!mem_read(cpu, cur, 4, &in)) {
        *bad_instruction = 0;
        return false;
    }
    *bad_instruction = in;
    cpu->pc = cpu->npc;
    cpu->npc += 4;
    ++cpu->count;

    uint32_t *r = cpu->reg;
    unsigned op = in >> 26, rs = (in >> 21) & 31, rt = (in >> 16) & 31;
    unsigned rd = (in >> 11) & 31, sh = (in >> 6) & 31, fn = in & 63;
    uint32_t uimm = in & 0xFFFFu;
    uint32_t simm = (uint32_t)(int32_t)(int16_t)in;
    uint32_t branch = cur + 4 + (simm << 2);
    uint32_t address = r[rs] + simm;
    uint32_t value;
    uint32_t *c0;

    switch (op) {
    case 0:
        switch (fn) {
        case 0x00: r[rd] = r[rt] << sh; break;
        case 0x02: r[rd] = r[rt] >> sh; break;
        case 0x03: r[rd] = (uint32_t)((int32_t)r[rt] >> sh); break;
        case 0x04: r[rd] = r[rt] << (r[rs] & 31); break;
        case 0x06: r[rd] = r[rt] >> (r[rs] & 31); break;
        case 0x07: r[rd] = (uint32_t)((int32_t)r[rt] >> (r[rs] & 31)); break;
        case 0x08: cpu->npc = r[rs]; break;
        case 0x09: value = r[rs]; r[rd] = cur + 8; cpu->npc = value; break;
        case 0x20: case 0x21: r[rd] = r[rs] + r[rt]; break;
        case 0x22: case 0x23: r[rd] = r[rs] - r[rt]; break;
        case 0x24: r[rd] = r[rs] & r[rt]; break;
        case 0x25: r[rd] = r[rs] | r[rt]; break;
        case 0x26: r[rd] = r[rs] ^ r[rt]; break;
        case 0x27: r[rd] = ~(r[rs] | r[rt]); break;
        case 0x2A: r[rd] = (int32_t)r[rs] < (int32_t)r[rt]; break;
        case 0x2B: r[rd] = r[rs] < r[rt]; break;
        default: return false;
        }
        break;
    case 1:
        if (rt == 0) {
            if ((int32_t)r[rs] < 0) cpu->npc = branch;
        } else if (rt == 1) {
            if ((int32_t)r[rs] >= 0) cpu->npc = branch;
        } else {
            return false;
        }
        break;
    case 2: cpu->npc = ((cur + 4) & 0xF0000000u) | ((in & 0x03FFFFFFu) << 2); break;
    case 3:
        r[31] = cur + 8;
        cpu->npc = ((cur + 4) & 0xF0000000u) | ((in & 0x03FFFFFFu) << 2);
        break;
    case 4: if (r[rs] == r[rt]) cpu->npc = branch; break;
    case 5: if (r[rs] != r[rt]) cpu->npc = branch; break;
    case 6: if ((int32_t)r[rs] <= 0) cpu->npc = branch; break;
    case 7: if ((int32_t)r[rs] > 0) cpu->npc = branch; break;
    case 8: case 9: r[rt] = r[rs] + simm; break;
    case 10: r[rt] = (int32_t)r[rs] < (int32_t)simm; break;
    case 11: r[rt] = r[rs] < simm; break;
    case 12: r[rt] = r[rs] & uimm; break;
    case 13: r[rt] = r[rs] | uimm; break;
    case 14: r[rt] = r[rs] ^ uimm; break;
    case 15: r[rt] = uimm << 16; break;
    case 16:
        c0 = cop0_reg(cpu, rd);
        if (rs == 0 && c0 != NULL) {
            r[rt] = *c0;
        } else if (rs == 4 && c0 != NULL) {
            *c0 = r[rt];
        } else {
            return false;
        }
        break;
    case 32:
        if (!mem_read(cpu, address, 1, &value)) return false;
        r[rt] = (uint32_t)(int32_t)(int8_t)value;
        break;
    case 33:
        if (!mem_read(cpu, address, 2, &value)) return false;
        r[rt] = (uint32_t)(int32_t)(int16_t)value;
        break;
    case 35: if (!mem_read(cpu, address, 4, &value)) return false; r[rt] = value; break;
    case 36: if (!mem_read(cpu, address, 1, &value)) return false; r[rt] = value; break;
    case 37: if (!mem_read(cpu, address, 2, &value)) return false; r[rt] = value; break;
    case 40: if (!mem_write(cpu, address, 1, r[rt])) return false; break;
    case 41: if (!mem_write(cpu, address, 2, r[rt])) return false; break;
    case 43: if (!mem_write(cpu, address, 4, r[rt])) return false; break;
    default: return false;
    }
    r[0] = 0;
    return true;
}

bool vizard_mips_interrupt(VizardMips *cpu, uint32_t cause_bits)
{
    if (cpu == NULL) {
        mips_contract_failure("vizard_mips_interrupt received a null CPU");
    }
    if (cpu->faulted || cpu->rom_bytes == 0) {
        fprintf(stderr, "Vizard: cannot run ISR (CPU faulted=%s, ISR bytes=%zu)\n",
                cpu->faulted ? "yes" : "no", cpu->rom_bytes);
        return false;
    }
    cpu->cause |= cause_bits;
    cpu->epc = VIZARD_MIPS_RETURN;
    cpu->status &= ~IM_GLOBAL;
    cpu->pc = VIZARD_MIPS_ISR_VECTOR;
    cpu->npc = cpu->pc + 4;

    uint32_t bad = 0;
    for (unsigned steps = 0; steps < VIZARD_MIPS_MAX_STEPS; ++steps) {
        if (cpu->pc == VIZARD_MIPS_RETURN) {
            return true;
        }
        uint32_t pc = cpu->pc;
        if (!step(cpu, &bad)) {
            fprintf(stderr, "Vizard: ISR fault at pc=0x%08X instruction=0x%08X\n", pc, bad);
            cpu->faulted = true;
            return false;
        }
    }
    fprintf(stderr, "Vizard: ISR did not return within %u instructions\n",
            VIZARD_MIPS_MAX_STEPS);
    cpu->faulted = true;
    return false;
}
