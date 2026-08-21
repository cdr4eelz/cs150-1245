#ifndef BENCHMARK_H_
#define BENCHMARK_H_

#include "types.h"
#include "mmio_intr_cop0.h"

#define CYCLE_COUNTER         (*((volatile uint32_t*)MM_CNT_CYCLE))
#define INSTRUCTION_COUNTER   (*((volatile uint32_t*)MM_CNT_INST))
#define COUNTER_RST           (*((volatile uint32_t*)MM_CNT_RESET))


void run_and_time(uint32_t (*f)());

#endif
