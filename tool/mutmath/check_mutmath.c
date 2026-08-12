#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "mutmath.h"

typedef uint32_t (*mul32u_p)(uint16_t, uint16_t);
typedef  int32_t (*mul32s_p)( int16_t,  int16_t);
typedef uint32_t (*sqr32u_p)(uint16_t);


// From MMULT (signed multiply)
int32_t times(int16_t aa, int16_t bb) {
    int32_t a_neg = aa < 0;
    int32_t b_neg = bb < 0;
    int32_t a = (a_neg) ? -aa : aa;
    int32_t b = (b_neg) ? -bb : bb;
    int32_t result = 0;
    while (b) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    if ((a_neg && !b_neg) || (!a_neg && b_neg)) { //Could use XOR?
        result = -result;
    }
    return result;
}


void test_mul32u(mul32u_p p, const char* name, uint16_t n, uint16_t m)
{
    uint32_t res = p(n, m);
    uint32_t ref = n * m;
    printf("mul32u %20s: %5u x %5u = %10u [%10u]  0x%8X [0x%8X]  %s%s\n",
        name, n, m, res, ref, res, ref,
        (res == ref) ? "" : "ERR-", (res == ref) ? "" : name);
}

void tests_mul32u(uint16_t n, uint16_t m)
{
    test_mul32u(&mut_mul32u_naive,      "naive",      n, m);
    test_mul32u(&mut_mul32u_quick,      "quick",      n, m);
    test_mul32u(&mut_mul32u_branchless, "branchless", n, m);
}


void test_mul32s(mul32s_p p, const char* name, int16_t n, int16_t m)
{
    int32_t res = p(n, m);
    int32_t ref = (int32_t)n * (int32_t)m;
    printf("mul32s %20s: %5d x %5d = %10d [%10d]  0x%8X [0x%8X]  %s%s\n",
        name, n, m, res, ref, res, ref,
        (res == ref) ? "" : "ERR-", (res == ref) ? "" : name);
}

void tests_mul32s(int16_t n, int16_t m)
{
    test_mul32s(&times,                 "times",      n, m);
    test_mul32s(&mut_mul32s_branchless, "branchless", n, m);
}


void test_sqr32u(sqr32u_p p, const char* name, uint16_t n)
{
    uint32_t res = p(n);
    uint32_t ref = ((uint32_t)n) * n;
    printf("sqr32u %20s: sqr(%5u) = %10u [%10u] | 0x%8X [0x%8X]  %s%s\n",
        name, n, res, ref, res, ref,
        (res == ref) ? "" : "ERR-", (res == ref) ? "" : name);
}

void tests_sqr32u(uint16_t n)
{
    test_sqr32u(&mut_sqr32u_mul,        "mul",        n);
    test_sqr32u(&mut_sqr32u_branchless, "branchless", n);
}


int main(int argc, char**argv) {
    
    //run_and_time(&mmult);

    printf("\nUnsigned Multiply:\n");
    tests_mul32u(  5,   4);
    tests_mul32u( -1, 100);
    tests_mul32u(  5,   5);
    tests_mul32u( -1,  -1);

    printf("\nSigned Multiply:\n");
    tests_mul32s(  5,  -4);
    tests_mul32s( -1,  -1);
    tests_mul32s(255, 100);
    tests_mul32s(-99,1000);

    printf("\nUnsigned Square\n");
    tests_sqr32u(    5);
    tests_sqr32u(   -1);
    tests_sqr32u(12345);
    tests_sqr32u( 9999);

    return 0;
}
