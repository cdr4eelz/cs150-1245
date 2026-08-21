#include "types.h"
#include "uart.h"
#include "benchmark.h"

#define DATA (int32_t *) 0x10018000

// Subset of ascii.c:
//   int8_t* uint32_to_ascii_hex(uint32_t x, int8_t* buf_ptr, uint32_t buf_len) -> buf_ptr[0]
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


// Minimal software tests as bios rom

typedef volatile uint32_t *vint32_p;

typedef void (*entry_t)(void);
#define BUF_LEN 256

uint32_t test_copy(int8_t* p_buf, uint32_t l_buf)
{
    register uint32_t v;
    vint32_p p3 = (vint32_p) 0x30000000;
    vint32_p p1 = (vint32_p) 0x10000000;
    v = *p1++; //Fetch via D-Cache
    *p3++ = v++; //Write to I&D
    v = (v & ~0xF0F0F0F0) | (0xABCDEF01 & 0xF0F0F0F0); //Expect AeCeEe0f
    *p3++ = v++; //Again to I&D
    v = *p1++; //Read 2nd value (masked combo) from D-Cache
    *p3++ = v; //Again to I&D for fun
    return v; //Return above expected value stored to I&D, fetched from D
}

void pios2() {
    int8_t buffer[BUF_LEN];
    uint32_t result, time, instructions;

    uwrite_int8('=');
    uint8_t tval = 0, cnt = 10;
    do {
        uwrite_int8s("[A");
        uwrite_int8(']');

        COUNTER_RST = 0;
        result = test_copy(buffer, BUF_LEN);
        time = CYCLE_COUNTER;
        instructions = INSTRUCTION_COUNTER;
        uwrite_int8s(" R:");
        uwrite_int8s(uint32_to_ascii_hex(result, buffer, BUF_LEN));
        uwrite_int8s(" C:");
        uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
        uwrite_int8s(" I:");
        uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));
        uwrite_int8(' ');
        uwrite_int8s("\r\n");

        tval = uread_int8();
    } while ((tval != ' ') && cnt--);

    uwrite_int8('*');
}
