#ifndef BENCHMARK_H_
#define BENCHMARK_H_

#include "types.h"
#include "mmio_intr_cop0.h"


void run_and_time(uint32_t (*f)());

#endif
