#include "parse.h"

#include "ascii.h"
#include "uart.h"

int8_t* read_n(int8_t*b, uint32_t n)
{
    for (uint32_t i = 0; i < n;  i++) {
        b[i] =  uread_int8();
    }
    b[n] = '\0';
    return b;
}

int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds)
{
    for (uint32_t i = 0; i < n; i++) {
        int8_t ch = uread_int8();
        for (uint32_t j = 0; ds[j] != '\0'; j++) {
            if (ch == ds[j]) {
                b[i] = '\0';
                return b;
            }
        }
        b[i] = ch;
    }
    b[n - 1] = '\0';
    return b;
}

void store(uint32_t address, uint32_t length)
{
    for (uint32_t i = 0; i*4 < length; i++) {
        int8_t buffer[9];
        int8_t* ascii_instruction = read_n(buffer,8);
        volatile uint32_t* p = (volatile uint32_t*)(address+i*4);
        *p = ascii_hex_to_uint32(ascii_instruction);
    }
}

void show_block(uint32_t address, uint8_t numWords, int8_t* bufMEM, uint32_t bufLEN)
{
    volatile uint32_t* p = (volatile uint32_t*)(address);
    for (uint32_t i = 0; i < numWords; i++) {
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
