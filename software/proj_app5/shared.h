#ifndef PROJ_APP5_SHARED_H_
#define PROJ_APP5_SHARED_H_

#include "types.h"

#define K_SHBUF_SIZEB      0x0100
#define K_SHBUF_ROLLOVER   0x00FF
#define K_MAGIC_VERSION    0xFEDBEEF1
#define K_CPU_HZ           50000000
#define K_TIMER_HZ         1
#define K_TIMER_CYC        (K_TIMER_HZ * K_CPU_HZ)
#define SM_BASE_ADDRESS    0x50000000u

#define SMO_magic          0x0000
#define SMO_stash0         0x0004
#define SMO_stash1         0x0008
#define SMO_stash2         0x000C
#define SMO_stash3         0x0010
#define SMO_flags          0x0014
#define SMO_RTC_count      0x0018
#define SMO_seconds        0x001C
#define SMO_clock          0x0020
#define SMO_buff_size      0x0024
#define SMO_buff_head      0x0028
#define SMO_buff_tail      0x002C
#define SMO_buff_data      0x0030

struct SM_DATA {
    volatile uint32_t magic;
    volatile uint32_t stash0, stash1, stash2, stash3;
    volatile uint32_t flags;
    volatile uint32_t RTC_count;
    volatile uint32_t seconds;
    volatile uint32_t clock;
    volatile uint32_t buff_size;
    volatile uint32_t buff_head;
    volatile uint32_t buff_tail;
    int8_t buff_data[K_SHBUF_SIZEB];
};

#ifdef VIZARD
extern struct SM_DATA vizard_shared;
#define SM_BASE (&vizard_shared)
#else
#define SM_BASE ((struct SM_DATA *)SM_BASE_ADDRESS)
#endif

#ifndef ISR_POLL
#define ISR_POLL(share) (1)
#endif

void SM_INIT(struct SM_DATA *sm);

#endif