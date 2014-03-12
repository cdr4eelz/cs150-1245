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


int8_t*  tok_word  ( void ) {
    return read_token(BUFFER_FIX, BUFFER_LEN, " \x0d");
}
uint32_t tok_hex32u( void ) {
    return ascii_hex_to_uint32(read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}
uint16_t tok_hex16u( void ) {
    return ascii_hex_to_uint16(read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}
uint8_t  tok_hex8u ( void ) {
    return ascii_hex_to_uint8 (read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}
uint32_t tok_dec32u( void ) {
    return ascii_dec_to_uint32(read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}
uint16_t tok_dec16u( void ) {
    return ascii_dec_to_uint16(read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}
uint8_t  tok_dec8u ( void ) {
    return ascii_dec_to_uint8 (read_token(BUFFER_FIX, BUFFER_LEN, " \x0d"));
}

void bufw_hex32u(uint32_t u32) {
    uwrite_int8s(uint32_to_ascii_hex(u32, BUFFER_FIX, BUFFER_LEN));
}
void bufw_hex16u(uint16_t u16) {
    uwrite_int8s(uint16_to_ascii_hex(u16, BUFFER_FIX, BUFFER_LEN));
}
void bufw_hex8u ( uint8_t u8 ) {
    uwrite_int8s( uint8_to_ascii_hex(u8,  BUFFER_FIX, BUFFER_LEN));
}
