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
