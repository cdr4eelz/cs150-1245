#ifndef VIZARD_HOST_H
#define VIZARD_HOST_H

#include <stdbool.h>
#include <stddef.h>

#define VIZARD_GPU_COMMAND_CAPACITY 4096u

void vizard_host_wait_pf_frame(unsigned int frame);
bool vizard_host_init(void);
void vizard_host_shutdown(void);
void vizard_host_report_error(const char *message);
bool vizard_host_failed(void);
void vizard_host_isr_status(unsigned int keep, unsigned int set);
void vizard_host_isr_compare(unsigned int compare);
struct SM_DATA;
bool vizard_host_poll(volatile struct SM_DATA *shared_data);
bool vizard_host_gpu_submit(const unsigned int *words, size_t word_count,
                            unsigned int frame);
void vizard_host_uart_write(unsigned char byte);
void vizard_host_set_frame_counter(unsigned int frame_counter);
int vizard_host_uart_read(void);

#define VIZARD_SUFFIX_INNER(name) name##_VIZARD
#define VIZARD_SUFFIX(name) VIZARD_SUFFIX_INNER(name)
#define uwait_ISR VIZARD_SUFFIX(uwait_ISR)
#define uwrite_int8s_ISR(src) uwrite_int8s_ISR_VIZARD((const char *)(src))

void uwait_ISR_VIZARD(void);
void uwrite_int8s_ISR_VIZARD(const char *src);

#endif