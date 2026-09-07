#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"

// Only declare ASCII function(s) as needed
#undef ASCII_WANT_DEC
#include "ascii_defs.inc"
DEFINE_TO_ASCII_HEX(uint32)

//TODO: Perhaps "#include" desired xxx_yyy_ISR() like above???

#define SM_BASE ((struct SM_DATA *) 0x50000000u)
#define K_SHBUF_SIZEB      0x0100
#define K_SHBUF_ROLLOVER   0x00FF
#define K_MAGIC_VERSION 0xFEDBEEF0

struct SM_DATA {
    volatile uint32_t magic; // Initialized to known value
    volatile uint32_t stash0, stash1, stash2, stash3; // Stash regs during interrupt
    volatile uint32_t flags; // 
    volatile uint32_t buff_size; // For comparison & sanity check
    volatile uint32_t buff_head; // Offset to circular buffer head,
    volatile uint32_t buff_tail; // Likewise for tail
    int8_t buff_data[K_SHBUF_SIZEB]; // The buffer itself (bytes NOT words)
};

/*
  REGISTER MAP:
    $0  $at $v0 $v1 $a0 $a1 $a2 $a3
    $t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7
    $s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7
            $t8 $t9 $gp $sp $fp $ra
  CALLEE preserves: s0-s7,gp,sp,fp,ra
*/

void SM_INIT(struct SM_DATA* sm) {
    sm->magic = K_MAGIC_VERSION; // Sanity check
    sm->stash0 = -1u;
    sm->stash1 = -1u;
    sm->stash2 = -1u;
    sm->stash3 = -1u;
    sm->flags = 0;
    sm->buff_size = K_SHBUF_SIZEB; // Sanity check
    sm->buff_head = 0;
    sm->buff_tail = 0;
}

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
void uwait_ISR(void) {
    struct SM_DATA* share = SM_BASE; //Should pass as argument???

    // Wait until interrupt based sending is done, BUT...
    //TODO: Should only check buffer IIF UATX interrupt on???
    while ((share->buff_tail != share->buff_head)
             || (!UTRAN_CTRL)) { } //Wait on prior sends
}

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
static int8_t tbuff[TBUF_SIZE];

void main() {
    struct SM_DATA* share = SM_BASE;

    //TODO: Clear "Cause" register???
    //TODO: Should macro mask "Cause" based on enabled "Status" bits???
    //TODO: Should "Cause" bits be cleared while "Status" is enabled???
    ISR_STATUS(0x00000000, 0x00000000); // Disable ALL interrupts & global

    // Initialize the shared memory block (shared with ISR handler)
    SM_INIT(share);

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);
    uwait_ISR(); // Get off to a clean start with nobody sending yet

    uwrite_int8s_ISR("\r\n\r\nPROJ-4:\r\n");
    uwrite_int8s_ISR("\n\rMAGIC: ");
    uwrite_int8s_ISR(uint32_to_ascii_hex(share->magic, tbuff, TBUF_SIZE));
    uwrite_int8s_ISR("\n\r");
    uwait_ISR();

    // Do interesting stuff here!

    uwait_ISR();
    ISR_STATUS(0x00000000, 0x00000000);
}

/* Resulting output..
> jal 60000000
...
...
[screen is terminating]
*/
