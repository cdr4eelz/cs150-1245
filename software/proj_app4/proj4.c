#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"

// Only declare ASCII function(s) as needed
#undef ASCII_WANT_DEC
#include "ascii_defs.inc"
DEFINE_TO_ASCII_HEX(uint32)

#define SM_BASE ((struct SM_DATA *) 0x50000000u)
#define K_BUFSIZEB      0x0010
#define K_BUFROLLOVER   0x000F
#define K_SHARED_MAGIC  0xFEEDBEEF

struct SM_DATA {
    volatile uint32_t magic; // Initialized to known value
    volatile uint32_t stash0; // Save registers during interrupt
    volatile uint32_t stash1; // typically saving $t0 $t1
    volatile uint32_t buff_size; // For comparison
    volatile uint32_t buff_head; // Offset to circular buffer head
    volatile uint32_t buff_tail; // Likewise for tail
    int8_t buff_data[K_BUFSIZEB]; // The buffer itself (bytes NOT words)
};

/*
  REGISTER MAP:
    $0  $at $v0 $v1 $a0 $a1 $a2 $a3
    $t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7
    $s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7
            $t8 $t9 $gp $sp $fp $ra
  CALLEE preserves: s0-s7,gp,sp,fp,ra
*/

//TODO: Put in UART library but keep it optional somehow
void uwrite_int8s_ISR(int8_t* src) { //Should use MAX/TIMEOUT?
    struct SM_DATA* share = SM_BASE;
    int8_t ch;

    while (ch = *src++) { // Repeat while not NULL
        if (UTRAN_CTRL) { // We can send directly
            UTRAN_DATA = ch; // Simple send direct to UART
        } else { // Utilize ring-buffer
            uint32_t head = share->buff_head;
            uint32_t nextHead = (head + 1) & K_BUFROLLOVER;
            while (nextHead == share->buff_tail) { } //Buffer is full
            share->buff_data[head] = ch;
            share->buff_head = nextHead;
        }
    }
}

void uwait_ISR(void) {
    struct SM_DATA* share = SM_BASE;

    // Wait until interrupt based sending is done
    while ((share->buff_tail != share->buff_head)
             || (!UTRAN_CTRL)) { } //Wait on prior send
}

//TODO: Put in simple string library (perhaps as INLINE)
int8_t* copy_string(int8_t* dst, int8_t* src, uint16_t maxLen) { //Add size check
    int8_t* base = dst;
    while ((*dst++ = *src++) && (maxLen--)) { }
    if (!maxLen) *dst = 0;
    return base;
}

#define SHORT_STRING "Not a very long string."
#define LONG_STRING "A Sample String Output: " \
            "More and more. " \
            "The quick brown fox jumped over the lazy barkey log. " \
            "The chicken rooster clucked instead of " \
            "making a normal sound. " \
            "This thing just goes on and on and on and on and on and..."
//            "on and on and on and never1234567890123456789"

#define TBUF_SIZE (256)

void main() {
    struct SM_DATA* share = SM_BASE;
    int8_t tbuff[TBUF_SIZE];

    //TODO: Clear "Cause" register???
    ISR_STATUS(0x00000000, 0x00000000);

    // Initialize into shared memory (shared with ISR handler)
    share->magic = K_SHARED_MAGIC;
    share->stash0 = -1u;
    share->stash1 = -1u;
    share->buff_size = K_BUFSIZEB;
    share->buff_head = 0;
    share->buff_tail = 0;
//    copy_string(&share->buff_data, LONG_STRING, K_BUFSIZEB - 1);

    while (!UTRAN_CTRL) { } //Wait until we can send...
    uwrite_int8s("\r\n\r\nPROJ-3:\r\n{"); //Output without interrupts
    while (!UTRAN_CTRL) { } //Wait until prior send is definitely done

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);

    uwrite_int8s_ISR(LONG_STRING);
    uwait_ISR();

    ISR_STATUS(0x00000000, 0x00000000);

    while (!UTRAN_CTRL) { } //Wait until prior send is definitely done
    UTRAN_DATA = '}';


    uwrite_int8s("\n\r\n\rMAGIC: ");
    uwrite_int8s(uint32_to_ascii_hex(share->magic, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\rHead: ");
    uwrite_int8s(uint32_to_ascii_hex(share->buff_head, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\rTail: ");
    uwrite_int8s(uint32_to_ascii_hex(share->buff_tail, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\r");
    //return;
}

/* Resulting output..

...
[screen is terminating]
*/
