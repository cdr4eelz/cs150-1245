#include "types.h"
#include "uart.h"

#define DATA (int32_t *) 0x10018000

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
#define BUF_LEN 256

int32_t countup(void)
{
    int8_t *buf2 = (int8_t*) DATA;
    int32_t sum = 0;
    uwrite_int8s("\r\nHold breath...\r\n");
    for (uint32_t i = 0; i < 22; i++) {
        uwrite_int8s(uint32_to_ascii_hex(i, buf2, BUF_LEN));
        sum += i;
        uwrite_int8s("\r\n");
    }
    uwrite_int8s("WHEW!!!\r\n");
    return sum;
}

int main(int argc, char**argv) {
    int8_t buffer[BUF_LEN];
    uint32_t result, time, instructions;

    uwrite_int8('=');
    uwrite_int8s("]");

    COUNTER_RST = 0;
    result = countup();
    time = CYCLE_COUNTER;
    instructions = INSTRUCTION_COUNTER;

    uwrite_int8s("Result: ");
    uwrite_int8s(uint32_to_ascii_hex(result, buffer, BUF_LEN));
    uwrite_int8s("\r\nCycle Count: ");
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s("\r\nInstruction Count: ");
    uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));
    uwrite_int8('[');
    uwrite_int8s("\r\n");

    return 0;
}

