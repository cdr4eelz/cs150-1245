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


#define BUFFER_LEN 128

typedef void (*entry_t)(void);


int main(void)
{
    int8_t buffer[BUFFER_LEN];

    uwrite_int8('=');
    uwrite_int8('>');
    {
        uint32_t a_src = 0x50000000;
        uint32_t a_dst = 0x30000000;
        uint32_t l_cpy = 0x00000800; //pmult currently about 0x0800, mmult currently about 0x1800

        uint32_t xor = copy_xor(a_src, a_dst, l_cpy);

        uwrite_int8s(uint32_to_ascii_hex(xor, buffer, BUFFER_LEN));
        uwrite_int8(' ');
    }
    {
        uint32_t addr = 0x10000000;
        entry_t start = (entry_t)(addr);
        start();
        uwrite_int8(' ');
        uwrite_int8('<');
    }
    return 0;
}
