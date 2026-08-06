#ifndef MUTMATH_H_
#define MUTMATH_H_

#include "types.h"

extern uint32_t mul32u(uint16_t const n, uint16_t const m);
extern uint32_t sqr32u(uint16_t const n);

//Can optionally define these yourself, otherwise, they
//  pick up weak alias from unoptimized mutmath.c code.

#endif
