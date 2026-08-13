#include "types.h"
#include "mutmath.h"
//#include "benchmark.h"
#include "ascii.h"
#include "uart.h"

//extern uint32_t mul32u(uint16_t const n, uint16_t const m);
//extern uint32_t sqr32u(uint16_t const n);

typedef void (*entry_t)(void);

void test_mul32u(uint16_t n, uint16_t m, uint32_t ref)
{
    int8_t buffer[256];
    uint32_t res = mul32u(n, m);
    
    uwrite_int8s("mul32u: ");
    uwrite_int8s(uint32_to_ascii_dec(n, buffer, 256));
    uwrite_int8s(" x ");
    uwrite_int8s(uint32_to_ascii_dec(m, buffer, 256));
    uwrite_int8s(" = ");
    uwrite_int8s(uint32_to_ascii_dec(res, buffer, 256));
    uwrite_int8s(" [");
    uwrite_int8s(uint32_to_ascii_dec(ref, buffer, 256));
    uwrite_int8s("]\n\r");
}

void test_sqr32u(uint16_t n, uint32_t ref)
{
    int8_t buffer[256];
    uint32_t res = sqr32u(n);

    uwrite_int8s("sqr32u: ");
    uwrite_int8s(uint32_to_ascii_dec(n, buffer, 256));
    uwrite_int8s(" = ");
    uwrite_int8s(uint32_to_ascii_dec(res, buffer, 256));
    uwrite_int8s(" [");
    uwrite_int8s(uint32_to_ascii_dec(ref, buffer, 256));
    uwrite_int8s("]\n\r");
}

void main() {
    //run_and_time(&mmult);

    uwrite_int8s("\n\rUnsigned Multiply:\n\r");
    test_mul32u(  5,   4, 20);
    test_mul32u( -1, 100, 6553500);
    test_mul32u(  5,   5, 25);
    test_mul32u( -1,  -1, 4294836225);

    uwrite_int8s("\n\rUnsigned Square\n\r");
    test_sqr32u(    5, 25);
    test_sqr32u(   -1, 4294836225);
    test_sqr32u(12345, 152399025);
    test_sqr32u( 9999, 99980001);

    uint32_t bios = 0x40000000;
    entry_t start = (entry_t) (bios);
    start();
    return 0;
}



/* Returns quotient = dividend / divisor (unsigned 32-bit).
 * Remainder can be obtained as: dividend - quotient * divisor
 * (or better, compute it inside the same loop).
 */
/*
static uint32_t udiv32(uint32_t dividend, uint32_t divisor)
{
    if (divisor == 0)          // optional safety
        return 0;

    uint32_t quotient  = 0;
    uint32_t remainder = 0;

    for (int i = 31; i >= 0; --i) {
        // Shift remainder left and bring down the next bit
        remainder = (remainder << 1) | ((dividend >> i) & 1u);

        if (remainder >= divisor) {
            remainder -= divisor;
            quotient  |= (1u << i);     // set the bit in the quotient
        }
    }
    return quotient;
}

typedef struct {
    uint32_t quot;
    uint32_t rem;
} divmod_t;

static divmod_t udivmod10(uint32_t n)
{
    divmod_t r = {0, 0};
    const uint32_t divisor = 10;

    for (int i = 31; i >= 0; --i) {
        r.rem = (r.rem << 1) | ((n >> i) & 1u);

        if (r.rem >= divisor) {
            r.rem  -= divisor;
            r.quot |= (1u << i);
        }
    }
    return r;
}

#include <stdint.h>

// paste udivmod10 from above

void uint32_to_string(uint32_t value, char *buf)
{
    if (value == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return;
    }

    char digits[10];
    int  count = 0;

    // Extract digits least-significant first using shift-based division
    while (value > 0) {
        divmod_t dm = udivmod10(value);
        digits[count++] = '0' + (char)dm.rem;   // remainder is the digit
        value = dm.quot;                        // continue with the quotient
    }

    // Reverse into the output buffer
    for (int i = 0; i < count; ++i)
        buf[i] = digits[count - 1 - i];
    buf[count] = '\0';
}

// Exact for all uint32_t values
static inline uint32_t udiv10_magic(uint32_t n)
{
    // 0xCCCCCCCD / 2^35  is a well-known reciprocal approximation
    return (uint32_t)(((uint64_t)n * 0xCCCCCCCDULL) >> 35);
}

// Remainder via the identity: n % 10 = n - (n/10)*10
static inline uint32_t umod10_magic(uint32_t n)
{
    uint32_t q = udiv10_magic(n);
    return n - q * 10;          // still no / or % operators
}

*/
