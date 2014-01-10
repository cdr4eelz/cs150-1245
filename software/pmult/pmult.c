#include "types.h"
#include "uart.h"

#define DATA (uint32_t *) 0x10018000

// Subset of ascii.c
#define DEFINE_TO_ASCII_HEX(type) \
int8_t* type##_to_ascii_hex(type##_t x, int8_t* buffer, uint32_t n) \
{ \
    uint32_t i = 0; \
    uint32_t m = ((sizeof(type##_t) / sizeof(uint8_t)) << 1); \
    for ( ; i < m && i + 1 < n; i++) { \
        int8_t t = (x >> ((m - 1 - i) << 2)) & 0xf; \
        if (t >= 0 && t <= 9) { \
            buffer[i] = t + '0'; \
        } \
        if (t >= 0xa && t <= 0xf) { \
            buffer[i] = (t - 0xa) + 'a'; \
        } \
    } \
    buffer[i] = '\0'; \
    return buffer; \
}
DEFINE_TO_ASCII_HEX(uint32)

// Subset of benchmark.c

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))


// Minimal activities of mmult

typedef void (*entry_t)(void);
#define BUF_LEN 128
#define CNTUP 22

int32_t countup0(void)
{
    int32_t sum = 0;
    for (uint32_t i = 0; i < CNTUP; i++) {
        sum += i;
    }
    return sum;
}

/*
int32_t countup1(void)
{
    int8_t *buf2 = (int8_t*) DATA;
    int32_t sum = 0;
    uwrite_int8s("\r\nCount1...\r\n");
    for (uint32_t i = 0; i < CNTUP; i++) {
        uint32_to_ascii_hex(i, buf2 + (i*32), 32);
        sum += i;
    }
    uwrite_int8s("Blab:");
    for (uint32_t i = 0; i < CNTUP; i++) {
        uwrite_int8s(buf2 + (i*32));
        uwrite_int8('|');
    }
    uwrite_int8s("WHEW!!!\r\n");
    return sum;
}

int32_t countup2(void)
{
    int8_t *buf2 = (int8_t*) DATA;
    int32_t sum = 0;
    uwrite_int8s("\r\nCount2...\r\n");
    for (uint32_t i = 0; i < CNTUP; i++) {
        uwrite_int8s(uint32_to_ascii_hex(i, buf2, BUF_LEN));
        sum += i;
        uwrite_int8('|');
    }
    uwrite_int8s("WHEW!!!\r\n");
    return sum;
}
*/

int main(int argc, char**argv) {
    int8_t buffer[BUF_LEN];
    uint32_t result, time, instructions;

    uwrite_int8('=');
    uwrite_int8s("][= ");

    uwrite_int8('0');
    uwrite_int8s("\r\nCount0...\r\n");
    COUNTER_RST = 0;
    result = countup0();
    time = CYCLE_COUNTER;
    instructions = INSTRUCTION_COUNTER;
    uwrite_int8s("WHEW! \r\n");
    uwrite_int8('R');
    uwrite_int8s(uint32_to_ascii_hex(result, buffer, BUF_LEN));
    uwrite_int8s(" : ");
    uwrite_int8('R');
    uwrite_int8s(uint32_to_ascii_hex(result, buffer, BUF_LEN));
    uwrite_int8s("\r\n");

    uwrite_int8('C');
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s(" : ");
    uwrite_int8('C');
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s("\r\n");

    uwrite_int8('I');
    uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));
    uwrite_int8s(" : ");
    uwrite_int8('I');
    uwrite_int8s(uint32_to_ascii_hex(instructions, (char*)DATA, BUF_LEN));
    uwrite_int8s("\r\n");

    uwrite_int8('\r');
    uwrite_int8('\n');

    return 0;
}

