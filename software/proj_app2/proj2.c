#include "types.h"
#include "uart.h"
#include "mmio_intr_cop0.h"

// Only declare ASCII function(s) as needed
#undef ASCII_WANT_DEC
#include "ascii_defs.inc"
DEFINE_TO_ASCII_HEX(uint32)

#define SM_BASE ((struct SM_DATA *) 0x50000000u)
#define K_BUFSIZEB 0x0100

struct SM_DATA {
    volatile uint32_t stash0;
    volatile uint32_t stash1;
    volatile uint32_t buff_size;
    volatile uint32_t buff_offset;
    int8_t buff_data[K_BUFSIZEB];
};

/*
  REGISTER MAP:
    $0  $at $v0 $v1 $a0 $a1 $a2 $a3
    $t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7
    $s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7
            $t8 $t9 $gp $sp $fp $ra
  CALLEE preserves: s0-s7,gp,sp,fp,ra
*/


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
            "making a normal sound." \
            "This thing just goes on and on and on and on and on and "
//            "on and on and on and never1234567890123456789"

#define TBUF_SIZE (256)

void main() {
    struct SM_DATA* share = SM_BASE;
    int8_t tbuff[TBUF_SIZE];

    // Copy into shared memory (shared with ISR handler)
    share->stash0 = -1u;
    share->stash1 = -1u;
    share->buff_size = K_BUFSIZEB;
    //copy_string(share->buff_data, "A Sample String Output\r\n");
    copy_string(share->buff_data, SHORT_STRING, K_BUFSIZEB - 1);
    share->buff_offset = 0;

    //TODO: Clear "Cause" register???
    ISR_STATUS(0x00000000, 0x00000000);

    uwrite_int8s("\r\n\r\nPROJ-2:\r\n"); //Output without interrupts
    while (!UTRAN_CTRL) { } //Wait until prior send is definitely done

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UATX);

    // Send a char manually to trigger UATX interrupt sequence
    while (!UTRAN_CTRL) { } //Wait until prior send is definitely done
    UTRAN_DATA = '{';
    //while (!UTRAN_CTRL) { } //Wait until prior send is definitely done

    // Wait until interrupt based sending is done
    while (share->buff_offset != K_BUFSIZEB) { }

    ISR_STATUS(0x00000000, 0x00000000);

    while (!UTRAN_CTRL) { } //Wait until prior send is definitely done
    UTRAN_DATA = '}';

/*
    uwrite_int8s("\n\rstash0: ");
    uwrite_int8s(uint32_to_ascii_hex(share->stash0, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\rstash1: ");
    uwrite_int8s(uint32_to_ascii_hex(share->stash1, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\r");
*/
    return;
}

/* Resulting output..

> jal 60000000


PROJ-2:
{Not a very long string.}

[Golt45.2.3]
...
[screen is terminating]
*/
