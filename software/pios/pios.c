#include "types.h"
#include "uart.h"
#include "ascii.h"
#include "benchmark.h"


void show_block(uint32_t address, int8_t* bufMEM, uint32_t bufLEN)
{
    volatile uint32_t* p = (volatile uint32_t*)(address);
    for (uint32_t i = 0; i < 16; i++) {
        if ((i%4)==0) {
            uwrite_int8s("\r\n");
            uwrite_int8s(uint32_to_ascii_hex((uint32_t) p, bufMEM, bufLEN));
            uwrite_int8(':');
        } else {
            uwrite_int8(' ');
        }
        uwrite_int8s(uint32_to_ascii_hex(*p++, bufMEM, bufLEN));
    }
}

uint32_t copy_xor(uint32_t pSRC, uint32_t pDST, uint32_t length)
{
    volatile uint32_t* s = (volatile uint32_t*)(pSRC);
    volatile uint32_t* d = (volatile uint32_t*)(pDST);
    uint32_t result = 0;
    for (uint32_t i = 0; i*4 < length; i++) {
        uint32_t val = *s++;
        result ^= val;
        if (pDST) {
            *d++ = val;
        }
    }
    return result;
}


typedef void (*entry_t)(void); //Jump to function ptr, hopefully something like "jalr"
#define BUFFER_LEN 128

#define DCACHE   ((uint32_t) 0x10000000)
#define ICACHE   ((uint32_t) 0x20000000)
#define XCACHE   ((uint32_t) 0x30000000)
#define CODE_SRC ((uint32_t) 0x50000000)
#define CODE_LEN ((uint32_t) 0x00002000)

int main(void)
{
    int8_t buffer[BUFFER_LEN];

    uwrite_int8('=');
    uwrite_int8('>');

    if (0) { // Dump ScratchPad DMEM
        show_block(CODE_SRC, buffer, BUFFER_LEN);
    }
    if (0) { // Dump D-Cache (sets up potentially different I/D-Cache content/stalling)
        show_block(DCACHE, buffer, BUFFER_LEN);
    }

    if (1) { // Copy from ScratchPad DMEM to I/D-Cache (simultaneous write)
        //pmult currently about 0x0800, mmult currently about 0x1800
        uint32_t xor = copy_xor(CODE_SRC, XCACHE, CODE_LEN);
        uwrite_int8('@');
        if (0) uwrite_int8s(uint32_to_ascii_hex(xor, buffer, BUFFER_LEN));
        uwrite_int8(' ');
    }

    if (0) { // Workaround: Copy to I-Cache only
        uint32_t xor = copy_xor(CODE_SRC, ICACHE, CODE_LEN);
        uwrite_int8('#');
        if (1) uwrite_int8s(uint32_to_ascii_hex(xor, buffer, BUFFER_LEN));
        uwrite_int8('-');
    }
    if (0) { // Workaround: Copy to D-Cache only
        uint32_t xor = copy_xor(CODE_SRC, DCACHE, CODE_LEN);
        uwrite_int8('$');
        if (1) uwrite_int8s(uint32_to_ascii_hex(xor, buffer, BUFFER_LEN));
        uwrite_int8('-');
    }
    if (0) { // Dump D-Cache
        show_block(DCACHE, buffer, BUFFER_LEN);
    }

    uwrite_int8('\r');
    uwrite_int8('\n');
    if (1) { // Jump to I-Cache copy of code
        uint32_t addr = DCACHE;
        entry_t start = (entry_t)(addr);
        start(); //Use function pointer
        uwrite_int8('*');
        uwrite_int8('1');
    }
    uwrite_int8('\r');
    uwrite_int8('\n');
    if (1) { // Jump to I-Cache copy of code a second time (less shtalling expected)
        uint32_t addr = DCACHE;
        entry_t start = (entry_t)(addr);
        start(); //Use function pointer
        uwrite_int8('*');
        uwrite_int8('2');
    }

L_HALT:
    goto L_HALT;
}
