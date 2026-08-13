#include "types.h"
#include "ascii_defs.h"
#include "uart.h"
//#include "stdio.h"

// COP0 interrupt MASKs
#define B_GLOBAL        0
#define B_UARX          10
#define B_UATX          11
#define B_RTC           14
#define B_TIMER         15
#define M_GLOBAL        (1 << B_GLOBAL)
#define M_UARX          (1 << B_UARX)
#define M_UATX          (1 << B_UATX)
#define M_RTC           (1 << B_RTC)
#define M_TIMER         (1 << B_TIMER)

#define SM_BASE ((struct SM_DATA_S *) 0x10010000)
#define K_BUFSIZEB 0x20

//PACKED caused awkward accesses: __attribute__ ((__packed__))
struct SM_DATA_S {
    uint32_t            volatile magic;
    uint32_t            volatile FlagMinSecState; //1-byte each
    uint32_t            volatile rtc;
    uint32_t            volatile count;
    uint32_t stash0, stash1, stash2, stash3;
    uint32_t            volatile bufsize;
    volatile uint8_t *  volatile head;
    volatile uint8_t *  volatile tail;
    uint32_t fill0;
    volatile uint8_t    buf[K_BUFSIZEB];
};

/*
  REGISTER MAP:
    $0  $at $v0 $v1 $a0 $a1 $a2 $a3
    $t0 $t1 $t2 $t3 $t4 $t5 $t6 $t7
    $s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7
            $t8 $t9 $gp $sp $fp $ra
  CALLEE preserves: s0-s7,gp,sp,fp,ra
*/

#define ISR_INIT                                \
    asm (                                       \
        "la     $t0,0xC0000000\n\t"             \
        "jalr   $t0\n\t"                        \
        "nop\n\t"                               \
        : /* No return */                       \
        : /* No args expected */                \
        : "t0","t1","a0","ra","memory" )

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

#define OUTC(CH)                                \
    asm (                                       \
        "la     $t0,0xC0000040\n\t"             \
        "jalr   $t0\n\t"                        \
        "or     $a0,$zero,%0\n\t"               \
        : /* No return */                       \
        : "r" (CH)                              \
        : "t0","t1","a0","ra","memory" )

void outc2(const uint8_t c) {
    OUTC(c);
}

void outc(const uint8_t c) {
    uint32_t priorSTATUS, ignoreSTATUS;
    struct SM_DATA_S * const pDATA = SM_BASE;
    volatile uint8_t * const buf = pDATA->buf;
    uint32_t const bufsize = pDATA->bufsize;
    volatile uint8_t * const hplast = buf + (bufsize-1);
    volatile uint8_t *hp, *hpnext;

    //Eliminate contention for a short while...
    ISR_STATUS(~M_GLOBAL, 0x00000000);

//  while (1) { //TODO: Give up after a while
        if (UTRAN_CTRL) { //UART available immediately?
            UTRAN_DATA = c; //Send directly (should trigger TX IRQ when done)
//          break;
        } else {
//          ISR_STATUS(0xFFFFFFFF, M_UATX | M_GLOBAL);
            hp = pDATA->head;
            hpnext = (hp >= hplast) ? buf : (hp+1);
//          ISR_STATUS(~M_GLOBAL, 0x00000000);
            if (hpnext == pDATA->tail) { //Is queue full?
                //give up & lose character; break;
            } else {
                *hp = c; //Enqueue...
                pDATA->head = hpnext; //...and advance real pointer.
            }
        }
//  }
    //...restore global interrupts & ensure TX enabled
    ISR_STATUS(0xFFFFFFFF, M_GLOBAL | M_UATX);
}

void outs(const int8_t *s) {
    int8_t c;
    while ((c = *s++) != '\0') {
        outc2((uint8_t) c);
    }
}

DEFINE_TO_ASCII_HEX(uint32)

void r100m() {
    volatile uint32_t i = 0, t = 10000000U; //10^7
    while (i < t) i++;
}
void r100f() {r100m();r100m();}
void v100m() {r100f();r100f();}
void v100f() {v100m();v100m();}

void timeit(uint8_t state, void (*f)(), volatile uint32_t *pCOUNT, int8_t *pBUF, uint32_t lBUF) {
    uint32_t tstart, tend;

    pBUF[0]=state; pBUF[1]=':'; pBUF[2]=' '; pBUF[3]='\0';
    outs(pBUF);

    tstart = *pCOUNT;
    (*f)();
    tend = *pCOUNT;

    outs(uint32_to_ascii_hex(tend-tstart, pBUF, lBUF));
    outs("\r\n");
}

//#define offsetof(type, member)  __builtin_offsetof (type, member)

void setSTATE(struct SM_DATA_S *pDATA, char newState) {
    pDATA->FlagMinSecState = (pDATA->FlagMinSecState & 0xFFFFFF00) | newState;
}
char getSTATE(struct SM_DATA_S *pDATA) {
    return (char) (pDATA->FlagMinSecState & 0x00FF);
}

#define BUF_LEN 128

//int main(int argc, char **argv) {
int main() {
    int8_t BUF[BUF_LEN];
    uint32_t ignoreSTATUS;
    volatile int quit = 0;
    struct SM_DATA_S *pDATA = SM_BASE;
//    uint32_t tHead = offsetof(struct SM_DATA_S, head);

    ISR_STATUS(~M_GLOBAL, 0x00000000);
    uwrite_int8s("\r\n\r\nWelcome...");
//    uwrite_int8s(uint32_to_ascii_hex(tHead, BUF, BUF_LEN));

    ISR_INIT; //Just initialize data structure
    setSTATE(pDATA, 's');

//    tHead = (uint32_t) pDATA->head;
//    uwrite_int8s(uint32_to_ascii_hex(tHead, BUF, BUF_LEN));

//    uwrite_int8('!');
    ISR_STATUS(0xFFFFFFFF, M_GLOBAL|M_UARX|M_UATX|M_RTC|M_TIMER);
    outs(" bench:\r\n");
//    uwrite_int8('@');

    while (!quit) {
        char lstate = getSTATE(pDATA);
        switch (lstate) {
            case 's': // "Silence", not directly user accessible
                break;

            case 'r': // register variable addi
                timeit(lstate, &r100m, &pDATA->count, BUF, BUF_LEN);
                break;
            case 'R': // register variable, plusone function call
                timeit(lstate, &r100f, &pDATA->count, BUF, BUF_LEN);
                break;
            case 'v': // volatile variable, addi
                //timeit(lstate, &v100m, &pDATA->count, BUF, BUF_LEN);
                outc2('-');// uwrite_int8('.');
                setSTATE(pDATA, 's');
                break;
            case 'V': // volatile variable, plusone function call
                //timeit(lstate, &v100f, &pDATA->count, BUF, BUF_LEN);
                //break;
            default: // print error? (optional)
                quit = 1;
                break;
        }
    }
    ISR_STATUS(~M_GLOBAL, 0x00000000);
    uwrite_int8s("\r\n\r\n***DONE.\r\n");
}

/*
//------------------------------------
r100M:
addi $t0, $0, 0
la $t1, 10^7
loop:
addi $t0, $t0, 1
bne $t0, $t1, loop
nop
//------------
lw $t0, b
nop
addi $t0, $t0, 1
sw $t0, b
//-----------
addi $a0, $t0, 0
jal addone
nop
addi $t0, $v0, 0
*/
