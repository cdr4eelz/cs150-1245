#ifndef MUTMATH_H_
#define MUTMATH_H_

#include "types.h"

extern uint32_t mul32(uint32_t n, uint32_t m);
extern uint32_t sqr32(uint32_t const n);

//Can optionally define these yourself, otherwise, they
//  pick up weak alias from unoptimized mutmath.c code.

#endif
