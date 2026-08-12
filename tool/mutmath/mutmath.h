#ifndef MUTMATH_H_
#define MUTMATH_H_

#include <stdint.h>

//#include "types.h"
/*
extern uint32_t mul32u(uint16_t const n, uint16_t const m);
extern uint32_t sqr32u(uint16_t const n);
*/

//Can optionally define these yourself, otherwise, they
//  pick up weak alias from unoptimized mutmath.c code.

uint32_t mut_mul32u_naive(uint16_t n, uint16_t m);
uint32_t mut_mul32u_quick(uint16_t a, uint16_t b);
uint32_t mut_mul32u_branchless(uint16_t m1, uint16_t m2);

int32_t  mut_mul32s_branchless(int16_t m1, int16_t m2);

uint32_t mut_sqr32u_mul(uint16_t n);
uint32_t mut_sqr32u_branchless(uint16_t x);

#endif
