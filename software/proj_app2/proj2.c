#include "types.h"
#include "uart.h"

// Only declare ASCII function(s) as needed
#undef ASCII_WANT_DEC
#include "ascii_defs.inc"
DEFINE_TO_ASCII_HEX(uint32)

//TODO: Move COP constants to shared header (plus asm version)
//{firetimer, firertc, irq_pf_frame, irq_gp_done, irq_UATX, irq_UARX};
// COP0 interrupt BIT-offsets
#define IB_GLOBAL   0
#define IB_UARX     10
#define IB_UATX     11
#define IB_GPU      12
#define IB_FRAME    13
#define IB_RTC      14
#define IB_TIMER    15
// COP0 interrupt MASKs
#define IM_GLOBAL       (1 << IB_GLOBAL)
#define IM_UARX         (1 << IB_UARX)
#define IM_UATX         (1 << IB_UATX)
#define IM_GPU          (1 << IB_GPU)
#define IM_FRAME        (1 << IB_FRAME)
#define IM_RTC          (1 << IB_RTC)
#define IM_TIMER        (1 << IB_TIMER)

#define SM_BASE ((struct SM_DATA *) 0x50000000u)
#define K_BUFSIZEB 0x0100

struct SM_DATA {
    volatile uint32_t stash0, stash1;
    uint32_t buff_size;
    uint32_t buff_offset;
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

#define ISR_STATUS(KEEP, SET)                   \
    asm (                                       \
        "li     $t0,%0\n\t"                     \
        "li     $t1,%1\n\t"                     \
        "mfc0   $t2,$12\n\t"                    \
        "and    $t2,$t2,$t0\n\t"                \
        "or     $t2,$t2,$t1\n\t"                \
        "mtc0   $t2,$12\n\t"                    \
        :                                       \
        : "i" (KEEP), "i" (SET)                 \
        : "t0","t1","t2" )

//TODO: Fix this function. Fails for unknown reason...
/*
uint32_t maskStatus(const uint32_t keep, const uint32_t set) {
    uint32_t prior;
    asm (
        "mfc0   %0,$12\n\t"
        "and    $t0,%0,%1\n\t"
        "or     $t0,$t0,%2\n\t"
        "mtc0   $t0,$12\n\t"
        : "=&r" (prior)
        : "r" (keep), "r" (set)
        : "t0"); //$t0==$8
    return prior;
}
*/

//TODO: Put in simple string library (perhaps as INLINE)
int8_t* copy_string(int8_t* dst, int8_t* src) {
    int8_t* base = dst;
    while (*dst++ = *src++) { }
    return base;
}

#define TBUF_SIZE (256)

void main() {
    volatile uint32_t volatile priorStatus;
    volatile struct SM_DATA* share = SM_BASE;
    int8_t tbuff[TBUF_SIZE];

    // Copy into shared memory (shared with ISR handler)
    share->stash0 = -1u;
    share->stash1 = -1u;
    share->buff_size = K_BUFSIZEB;
    share->buff_offset = 0;
    copy_string(share->buff_data, "Sample String Output\r\n");

    //TODO: Clear "Cause" register
    ISR_STATUS(0x00000000, 0x00000000);

    uwrite_int8s("\r\n\r\nPROJ1...\r\n"); //Output without interrupts
    if (share->stash0 != -1u) { return; }
    while (!UTRAN_CTRL) { }
    UTRAN_DATA = '1';
    while (!UTRAN_CTRL) { }
    if (share->stash0 != -1u) { return; }
    UTRAN_DATA = 'a';
    while (!UTRAN_CTRL) { }

    ISR_STATUS(0x00000000, IM_GLOBAL | IM_UARX | IM_UATX);
    if ((share->stash0 != -1u) || (share->stash1 != -1u)) { return; }

    while (!UTRAN_CTRL) { }
    UTRAN_DATA = '2'; // This should trigger a subsequent UATX interrupt
    // The UATX handler stashes CAUSE & STATUS in stash0/1
    // The UATX outputs one '#' and leaves UATX interrupt DISABLED
    //     so no more UATX chars sent and the "b" below is sent...
    while ((share->stash0 == -1u) && (share->stash1 == -1u)) { }
    //ISR_STATUS(0x00000000, 0x00000000);
    while (!UTRAN_CTRL) { }
    UTRAN_DATA = 'b';
    while (!UTRAN_CTRL) { }

    ISR_STATUS(0x00000000, 0x00000000);

    uwrite_int8s("\n\rstash0: ");
    uwrite_int8s(uint32_to_ascii_hex(share->stash0, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\rstash1: ");
    uwrite_int8s(uint32_to_ascii_hex(share->stash1, tbuff, TBUF_SIZE));
    uwrite_int8s("\n\r");

    while (!UTRAN_CTRL) { }
    UTRAN_DATA = '3';
    while (!UTRAN_CTRL) { }
    UTRAN_DATA = 'c';

    return;
}

/* Resulting output..
> jal 10000000


PROJ1...
1a2#b
stash0: 00000800
stash1: 00000c00
3c

[Golt45.2.2]
...
[screen is terminating]
*/
