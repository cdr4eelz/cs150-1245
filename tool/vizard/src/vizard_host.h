#ifndef VIZARD_HOST_H
#define VIZARD_HOST_H

#include <stdbool.h>
#include <stddef.h>

#define VIZARD_GPU_COMMAND_CAPACITY 4096u

bool vizard_host_init(void);
void vizard_host_shutdown(void);
void vizard_host_isr_status(unsigned int keep, unsigned int set);
void vizard_host_isr_compare(unsigned int compare);
bool vizard_host_poll(volatile unsigned int *seconds, volatile unsigned int *clock,
                      volatile unsigned int *rtc_count);
bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame);
void vizard_host_uart_write(unsigned char byte);
int vizard_host_uart_read(void);

#define VIZARD_SUFFIX_INNER(name) name##_VIZARD
#define VIZARD_SUFFIX(name) VIZARD_SUFFIX_INNER(name)
#define uwait_ISR VIZARD_SUFFIX(uwait_ISR)
#define uwrite_int8s_ISR VIZARD_SUFFIX(uwrite_int8s_ISR)

void uwait_ISR_VIZARD(void);
void uwrite_int8s_ISR_VIZARD(int8_t *src);

#endif