#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "shared.h"
#ifdef VIZARD
#include "vizard_host.h"
#endif

// Only declare ASCII function(s) as needed
// #undef ASCII_WANT_DEC
// #include "ascii_defs.inc"
// DEFINE_TO_ASCII_HEX(uint32)

//TODO: Perhaps "#include" desired xxx_yyy_ISR() like above???

/*
  REGISTER MAP:
    $0  $at $v0 $v1 $a0 $a1 $a2 $a3
    $t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7
    $s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7
            $t8 $t9 $gp $sp $fp $ra
  CALLEE preserves: s0-s7,gp,sp,fp,ra
*/

// Set "Compare" to zero so interrupt fires on first opportunity

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

#define TBUF_SIZE (256)
static int8_t tbuff[TBUF_SIZE]; // Can be confusing as to where this gets located

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

void frame_gp_generate(uint32_t frame) {

}

void frame_gp_render(uint32_t frame) {

}


void main() {
    struct SM_DATA* share = SM_BASE;
    uint32_t tClock, prevClock;

    //TODO: Clear "Cause" register???
    //TODO: Should macro mask "Cause" based on enabled "Status" bits???
    //TODO: Should "Cause" bits be cleared while "Status" is enabled???
    ISR_STATUS(0x00000000, 0x00000000); // Disable ALL interrupts & global

    // Initialize the shared memory block (shared with ISR handler)
    SM_INIT(share);
    
    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);
    uwait_ISR(); // Get off to a clean start with nobody sending yet

    uwrite_int8s_ISR("\r\n\r\nPROJ-4:\r\n");
    uwrite_int8s_ISR("MAGIC: ");
    uwrite_int8s_ISR(uint32_to_ascii_hex(share->magic, tbuff, TBUF_SIZE));
    uwrite_int8s_ISR("\n\r");
    uwait_ISR();

    ISR_COMPARE(K_TIMER_CYC); // This implicitly resets "Count" to zero
    //NOTE: We set "Compare" here on init, but after that the ISR handles it

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX | IM_UARX | IM_RTC | IM_TIMER); //GPU?
    
    tClock = prevClock = 0;
    while (ISR_POLL(share)) {
        tClock = share->clock;
        if (tClock != prevClock) {
            //TODO: Conditional based on a flag
            if (1) uwrite_clock(tClock);
            prevClock = tClock; // Advance whether or not printing enabled
        }

        // Temporarily utilize just one frame
        frame_gp_generate(1);
        frame_gp_render(1);
    }

    uwait_ISR();
    ISR_STATUS(0x00000000, 0x00000000);
}

/* Resulting output..
> jal 60000000
...
...
[screen is terminating]
*/
