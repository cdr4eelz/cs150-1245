#ifndef VIZARD_HOST_H
#define VIZARD_HOST_H

#include <stdbool.h>
#include <stddef.h>

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

#define VIZZARD_SUFFIX_INNER(name) name##_VIZZARD
#define VIZZARD_SUFFIX(name) VIZZARD_SUFFIX_INNER(name)
#define uwait_ISR VIZZARD_SUFFIX(uwait_ISR)
#define uwrite_int8s_ISR VIZZARD_SUFFIX(uwrite_int8s_ISR)

void uwait_ISR_VIZZARD(void);
void uwrite_int8s_ISR_VIZZARD(int8_t *src);

#endif