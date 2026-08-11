#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "mutmath.h"


// From MMULT (signed)
int32_t times(int32_t a, int32_t b) {
    int32_t a_neg = a < 0;
    int32_t b_neg = b < 0;
    int32_t result = 0;
    if (a_neg) a = -a;
    if (b_neg) b = -b;
    while (b) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    if ((a_neg && !b_neg) || (!a_neg && b_neg)) {
        result = -result;
    }
    return result;
}

//typedef void (*entry_t)(void);

/*
uint32_t mut_mul32u_naive(uint16_t n, uint16_t m);
uint32_t mut_mul32u_branchless(uint16_t m1, uint16_t m2);
uint32_t mut_mul32u_quick(uint16_t a, uint16_t b);

uint32_t mut_sqr32u_naive(uint16_t n);
uint32_t mut_sqr32u_branchless(uint16_t x);
*/

typedef uint32_t (*mul32u_p)(uint16_t, uint16_t);
typedef uint32_t (*sqr32u_p)(uint16_t);

void test_mul32u(mul32u_p p, const char* name, uint16_t n, uint16_t m)
{
    uint32_t res = p(n, m);
    uint32_t ref = n * m;
    printf("mul32u %20s: %5u x %5u = %10u [%10u]  0x%8X [0x%8X]  %s\n", name, n, m, res, ref, res, ref, (res == ref) ? "" : "ERR");
}

void tests_mul32u(uint16_t n, uint16_t m)
{
    test_mul32u(&mut_mul32u_naive,      "naive",      n, m);
    test_mul32u(&mut_mul32u_quick,      "quick",      n, m);
    test_mul32u(&mut_mul32u_branchless, "branchless", n, m);

    int32_t s_res = times((int32_t)n,(int32_t) m);
    int32_t s_ref = (int32_t)n * (int32_t)m;
    printf("times  %20s: %5d x %5d = %10d [%10d]  0x%8X [0x%8X]  %s\n", "times", n, m, s_res, s_ref, s_res, s_ref, (s_res == s_ref) ? "" : "ERR");
}

void test_sqr32u(sqr32u_p p, const char* name, uint16_t n)
{
    uint32_t res = p(n);
    uint32_t ref = ((uint32_t)n) * n;
    printf("sqr32u %20s: %5u ^ 2 = %10u [%10u] | 0x%8X [0x%8X]  %s\n", name, n, res, ref, res, ref, (res == ref) ? "" : "ERR");
}

void tests_sqr32u(uint16_t n)
{
    test_sqr32u(&mut_sqr32u_naive,      "naive",      n);
    test_sqr32u(&mut_sqr32u_branchless, "branchless", n);
}

int main(int argc, char**argv) {
    
    //run_and_time(&mmult);
    tests_mul32u( 5,   4);
    tests_mul32u(-1, 100);
    tests_mul32u( 5,   5);
    tests_mul32u(-1,  -1);
    printf("\n");
    tests_sqr32u(5);
    tests_sqr32u(-1);
    tests_sqr32u(12345);
    tests_sqr32u(9999);

    return 0;
}
