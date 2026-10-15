#ifndef PROJ_SHARED6_H_
#define PROJ_SHARED6_H_

#include "types.h"

#define K_SHBUF_SIZEB      (0x0100u)
#define K_SHBUF_ROLLOVER   (0x00FFu)
#define K_MAGIC_VERSION    (0xFEDBEEF1u)
#define K_CPU_HZ           (50000000u)
#define K_TIMER_HZ         (1u)
#define K_TIMER_CYC        ( (K_TIMER_HZ) * (K_CPU_HZ) )
#define SM_BASE_ADDRESS    (0x50000000u)

#define SMO_magic          (0x0000u)
#define SMO_stash0         (0x0004u)
#define SMO_stash1         (0x0008u)
#define SMO_stash2         (0x000Cu)
#define SMO_stash3         (0x0010u)
#define SMO_state           (0x0014u)
#define SMO_flags           (0x0016u)
#define SMO_RTC_count      (0x0018u)
#define SMO_seconds        (0x001Cu)
#define SMO_clock          (0x0020u)
#define SMO_player_y        (0x0024u)
#define SMO_player_x        (0x0026u)
#define SMO_buff_size      (0x0028u)
#define SMO_buff_head      (0x002Cu)
#define SMO_buff_tail      (0x0030u)
#define SMO_buff_data      (0x0034u)

struct SM_DATA {
    volatile uint32_t magic;
    volatile uint32_t stash0, stash1, stash2, stash3;
    volatile uint16_t  state;
    volatile uint16_t  flags;
    volatile uint32_t RTC_count;
    volatile uint32_t seconds;
    volatile uint32_t clock;
    volatile uint16_t  player_y;
    volatile uint16_t  player_x;
    volatile uint32_t buff_size;
    volatile uint32_t buff_head;
    volatile uint32_t buff_tail;
    int8_t buff_data[K_SHBUF_SIZEB];
};

// Bit numbers (offsets?) for {SMO/SMA}_flags:
#define SMB_flags_pause     (0)
#define SMB_flags_notimer   (1)
// Flag masks for testing or setting flags
#define SMM_flags_pause     ((uint16_t)(1u << SMB_flags_pause))
#define SMM_flags_notimer   ((uint16_t)(1u << SMB_flags_notimer))
// Inverted flag masks, kept at 16-bits, for clearing flags
#define SMI_flags_pause     ((uint16_t)(~SMM_flags_pause))
#define SMI_flags_notimer   ((uint16_t)(~SMM_flags_notimer))


#ifdef VIZARD
extern struct SM_DATA vizard_shared;
#define SM_BASE (&vizard_shared)
#else
#define SM_BASE ((struct SM_DATA *)SM_BASE_ADDRESS)
#endif

#ifndef ISR_POLL
#define ISR_POLL(share) (1)
#endif

void SM_INIT6(struct SM_DATA *sm);

void uwrite_int8s_ISR(int8_t* src);
void uwait_ISR(void);
void uwrite_clock_ISR(uint32_t clk_bcd);

#define TBUF_SIZE (256)
extern int8_t tbuff[TBUF_SIZE]; // Can be confusing as to where this gets located

#endif
