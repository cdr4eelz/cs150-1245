#include "shared.h"
#include "uart.h"
#ifdef VIZARD
#include "vizard_host.h"
#endif

#define SM_CHECK_OFFSET(member, expected) \
    typedef char sm_offset_check_##member[ \
        (__builtin_offsetof(struct SM_DATA, member) == (expected)) ? 1 : -1]

SM_CHECK_OFFSET(magic, SMO_magic);
SM_CHECK_OFFSET(stash0, SMO_stash0);
SM_CHECK_OFFSET(stash1, SMO_stash1);
SM_CHECK_OFFSET(stash2, SMO_stash2);
SM_CHECK_OFFSET(stash3, SMO_stash3);
SM_CHECK_OFFSET(flags, SMO_flags);
SM_CHECK_OFFSET(RTC_count, SMO_RTC_count);
SM_CHECK_OFFSET(seconds, SMO_seconds);
SM_CHECK_OFFSET(clock, SMO_clock);
SM_CHECK_OFFSET(buff_size, SMO_buff_size);
SM_CHECK_OFFSET(buff_head, SMO_buff_head);
SM_CHECK_OFFSET(buff_tail, SMO_buff_tail);
SM_CHECK_OFFSET(buff_data, SMO_buff_data);
typedef char sm_size_check[(sizeof(struct SM_DATA) == SMO_buff_data + K_SHBUF_SIZEB) ? 1 : -1];

#ifdef VIZARD
struct SM_DATA vizard_shared;
#endif

void SM_INIT(struct SM_DATA *sm)
{
    sm->magic = K_MAGIC_VERSION;
    sm->stash0 = -1u;
    sm->stash1 = -1u;
    sm->stash2 = -1u;
    sm->stash3 = -1u;
    sm->flags = 0;
    sm->seconds = 0;
    sm->clock = 0;
    sm->buff_size = K_SHBUF_SIZEB;
    sm->buff_head = 0;
    sm->buff_tail = 0;
}


#ifndef VIZARD
//TODO: Put in UART library but keep it optional somehow
void uwrite_int8s_ISR(int8_t* src) { //Should use MAX/TIMEOUT???
    struct SM_DATA* share = SM_BASE; //Should pass as argument???
    int8_t ch;

    while (ch = *src++) { // Repeat while not NULL
        if (UTRAN_CTRL) { // We can send directly
            UTRAN_DATA = ch; // Simple send direct to UART
        } else { // Utilize ring-buffer
            uint32_t head = share->buff_head;
            uint32_t nextHead = (head + 1) & K_SHBUF_ROLLOVER;
            while (nextHead == share->buff_tail) { } //Buffer is full
            share->buff_data[head] = ch;
            share->buff_head = nextHead;
        }
    }
    // Should there be a return a value (indicating success vs. timeout)?
}
#endif

/* More complicated send (attempt to handle bad situations gracefully)...
void uwrite_int8s_ISR(int8_t* src) {
    struct SM_DATA* share = SM_BASE;
    int8_t ch;

    while (ch = *src) {       // Repeat while not NULL
        if (UTRAN_CTRL) {       // We can send right now
            UTRAN_DATA = ch;    // Send direct via UART TX
            src++;              // Advance within source str
        } else {                // Utilize ring-buffer...
            uint32_t head = share->buff_head;
            uint32_t nextHead = (head + 1) & K_SHBUF_ROLLOVER;
            if (nextHead == share->buff_tail) { // FULL
                //TODO: Could count/timeout then give up???
                //TODO: Ensure UATX interrupt is enabled???
                // if give up, then break; // Break early
            } else {
                share->buff_data[head] = ch;
                share->buff_head = nextHead;
                src++;          // Advance
            }
        }
    }
}
*/

// Drain the ring-buffer and UART ready flag:
#ifndef VIZARD
void uwait_ISR(void) {
    struct SM_DATA* share = SM_BASE; //Should pass as argument???

    // Wait until interrupt based sending is done, BUT...
    //TODO: Should only check buffer IIF UATX interrupt on???
    while ((share->buff_tail != share->buff_head)
             || (!UTRAN_CTRL)) { } //Wait on prior sends
}
#endif

/*  UNNEEDED FUNCTION? Certainly should be optional or inline/macro if defined
//TODO: Put in simple string library (perhaps as INLINE)
int8_t* copy_string(int8_t* dst, int8_t* src, uint16_t maxLen) { //Add size check
    int8_t* base = dst;
    while ((*dst++ = *src++) && (maxLen--)) { }
    if (!maxLen) *dst = 0;
    return base;
}
*/

void uwrite_clock(uint32_t clk_bcd) {
    uwrite_int8s_ISR("\n\rCLK: ");
    // Assemble clock string "mm:ss" in tbuff
    tbuff[0] = '0' + ((clk_bcd >> 12) & 0x0F);
    tbuff[1] = '0' + ((clk_bcd >>  8) & 0x0F);
    tbuff[2] = ':';
    tbuff[3] = '0' + ((clk_bcd >>  4) & 0x0F);
    tbuff[4] = '0' + ((clk_bcd >>  0) & 0x0F);
    tbuff[5] = 0;
    uwrite_int8s_ISR(tbuff);
    uwrite_int8s_ISR("\n\r");
}
