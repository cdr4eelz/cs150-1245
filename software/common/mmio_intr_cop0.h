#ifndef MMIO_INTR_COP0_H_
#define MMIO_INTR_COP0_H_

#ifdef VIZARD
#include <stdbool.h>
#include <stdlib.h>
#include <stdint.h>
#else
#include "types.h"
#endif

// C HEADER file for Coprocessor, Interrupts & MMIO

// COP0 reg names for inline "__asm__" sections (inserted as strings):
#define COP0_Count       "$9"   // There can also be "official" names
#define COP0_Compare    "$11"   //   like "C0_Compare" and although
#define COP0_Status     "$12"   //   these names should match the
#define COP0_Cause      "$13"   //   official register names, we use
#define COP0_EPC        "$14"   //   numbers to ensure to match HW.
// Example:
// __asm__ __volatile__("mfc0 %0, " COP0_Count : "=r"(cycle_count));

// COP0 interrupt BIT-offsets (STATUS & CAUSE)
#define IB_GLOBAL   (0)
#define IB_UARX     (10)
#define IB_UATX     (11)
#define IB_GPU      (12)
#define IB_FRAME    (13)
#define IB_RTC      (14)
#define IB_TIMER    (15)

// COP0 interrupt MASKs (STATUS & CAUSE)
#define IM_GLOBAL       (1 << IB_GLOBAL)
#define IM_UARX         (1 << IB_UARX)
#define IM_UATX         (1 << IB_UATX)
#define IM_GPU          (1 << IB_GPU)
#define IM_FRAME        (1 << IB_FRAME)
#define IM_RTC          (1 << IB_RTC)
#define IM_TIMER        (1 << IB_TIMER)
#define     IM_POSSIBLE     (0xFC00u) // All except IM_GLOBAL


/*  Verilog MemMapIO (word offsets and mapped byte addresses)

//                  Table 2: I/O Memory Map
//ADDR-12 ADDRESS-32      FUNCTION                      ACCESS
localparam [5:0]            //   DATA-ENCODING/DESC
//h000    32'h80000000    UART xmit cntl                Read
    A_D0TxReady     =6'h00, // {31'b0, DataInReady}
//h001    32'h80000004    UART recv cntl                Read
    A_D0RxValid     =6'h01, // {31'b0, DataOutValid}
//h002    32'h80000008    UART xmit data                Write
    A_D0TxData      =6'h02, // {24'b0, DataIn}
//h003    32'h8000000c    UART recv data                Read
    A_D0RxData      =6'h03, // {24'b0, DataOut}
//h004    32'h80000010    Cycle count                   Read
    A_CntCycle      =6'h04, // Total number of cycles
//h005    32'h80000014    Instr count                   Read
    A_CntInst       =6'h05, // Number of instructions executed
//h006    32'h80000018    Reset counts                  Write
    A_ResetCnt      =6'h06, // N/A (any byte will trigger)
//h014    32'h80000050    PF_FRAME                      Read active / Write next
    A_PFFrame       =6'h14, // PixelFeeder frame# (ADDR is frame# * 0x0040_0000)
//h015    32'h80000054    GP_FRAME                      Write
    A_GPFrame       =6'h15, // Stored, then "captured" along with GP_CODE on launch
//h016    32'h80000058    GP_CODE                       Write
    A_GPCode        =6'h16, // Write also launches GraphicsProcessor
//h017    32'h8000005C    GPU status                    Read
    A_GPUStatus     =6'h17, // See Memory150 for concatenated signals
//h020    32'h80000080    Random 32-bits from PRNG      Read / write seed
    A_Random32      =6'h20, // A LFSR output with writeable seed
//h021    32'h80000084    HALT value                    Read / write
    A_HaltVal       =6'h21; // Store value for BIOS or emulator to see
*/

// MEMORY-MAPPED IO locations (byte offsets)
#define MMIO_BASE   (0x80000000u)
#define OW_UATX_READY   (0x0000u)
#define OW_UARX_VALID   (0x0004u)
#define OW_UATX_DATA    (0x0008u)
#define     OB_UATX_DATA    (OW_UATX_DATA+3)
#define OW_UARX_DATA    (0x000Cu)
#define     OB_UARX_DATA    (OW_UARX_DATA+3)
#define OW_CNT_CYCLE    (0x0010u)
#define OW_CNT_INST     (0x0014u)
#define OW_CNT_RESET    (0x0018u)
#define OW_PF_FRAME     (0x0050u)
#define OW_GP_FRAME     (0x0054u)
#define OW_GP_GCODE     (0x0058u)
#define OW_GP_STATE     (0x005Cu)
#define OW_RANDOM32     (0x0080u)
#define OW_HALTVAL      (0x0084u)

// MEMORY-MAPPED IO locations (addresses)
#define MM_UATX_READY   (MMIO_BASE + OW_UATX_READY)
#define MM_UARX_VALID   (MMIO_BASE + OW_UARX_VALID)
#define     MM_UART_RVA_BIT     (0x0001)
#define MM_UATX_DATA    (MMIO_BASE + OW_UATX_DATA)
#define MM_UARX_DATA    (MMIO_BASE + OW_UARX_DATA)
#define     MM_UART_DATA_BYTE   (0x00FF)
#define MM_CNT_CYCLE    (MMIO_BASE + OW_CNT_CYCLE)
#define MM_CNT_INST     (MMIO_BASE + OW_CNT_INST)
#define MM_CNT_RESET    (MMIO_BASE + OW_CNT_RESET)
#define MM_PF_FRAME     (MMIO_BASE + OW_PF_FRAME)
#define MM_GP_FRAME     (MMIO_BASE + OW_GP_FRAME)
#define MM_GP_GCODE     (MMIO_BASE + OW_GP_GCODE)
#define MM_GP_STATE     (MMIO_BASE + OW_GP_STATE)
#define MM_RANDOM32     (MMIO_BASE + OW_RANDOM32)
#define MM_HALTVAL      (MMIO_BASE + OW_HALTVAL)


//TODO: Should we implicitly AND "Cause" with "KEEP" mask?
//    :   In other words, ensure a waiting interrupt doesn't fire.

#ifdef VIZARD
void vizard_host_isr_status(unsigned int keep, unsigned int set);
void vizard_host_isr_compare(unsigned int compare);
struct SM_DATA; //TODO: Reference real definition
bool vizard_host_poll(volatile struct SM_DATA *shared_data);
unsigned int vizard_host_cnt_cycle(void);
unsigned int vizard_host_cnt_inst(void);
void vizard_host_cnt_reset(void);
#define ISR_STATUS(KEEP, SET)   vizard_host_isr_status((KEEP), (SET))
#define ISR_COMPARE(COMPARE)    vizard_host_isr_compare(COMPARE)
#define HALT(HALTVAL)           exit(HALTVAL)
#define ISR_POLL(share)         vizard_host_poll((share))
#define CYCLE_COUNTER           (vizard_host_cnt_cycle())
#define INSTRUCTION_COUNTER     (vizard_host_cnt_inst())
#define COUNTER_RST             (*(vizard_host_cnt_reset(), &(uint32_t){0}))

#else // VIZARD

//TODO: Use named variables for clarity.
#define ISR_STATUS(KEEP, SET)                   \
    __asm__ __volatile__ (                      \
        "li     $t0,%0"                 "\n\t"  \
        "mfc0   $t1," COP0_Status       "\n\t"  \
        "and    $t1,$t1,$t0"            "\n\t"  \
        "li     $t0,%1"                 "\n\t"  \
        "or     $t1,$t1,$t0"            "\n\t"  \
        "mtc0   $t1," COP0_Status       "\n\t"  \
        :                                       \
        : "i" (KEEP), "i" (SET)                 \
        : "t0","t1", "memory"                   \
    )

// ISR_COMPARE implicitly resets "Count"
#define ISR_COMPARE(COMPARE)                    \
    __asm__ __volatile__ (                      \
        "li     $t0,%0"                 "\n\t"  \
        "mtc0   $zero," COP0_Count      "\n\t"  \
        "mtc0   $t0," COP0_Compare      "\n\t"  \
        :                                       \
        : "i" (COMPARE)                         \
        : "t0", "memory"                        \
    )

// Disables interrupts, stashes retval & jumps to BIOS base
//TODO: Consider special BIOS entrypoint for halting???
//NOTE: Passing MM_HALTVAL because it is "C" format, not GAS
#define HALT(HALTVAL) do {                      \
    __asm__ __volatile__ (                      \
        "mtc0   $zero," COP0_Status     "\n\t"  \
        "li     $t0,%0"                 "\n\t"  \
        "li     $t1,%1"                 "\n\t"  \
        "sw     $t0,0($t1)"             "\n\t"  \
        "la     $t0,0x40000000"         "\n\t"  \
        "jr     $t0"                    "\n\t"  \
        "nop"                           "\n\t"  \
        :                                       \
        : "i" (HALTVAL) , "i" (MM_HALTVAL)      \
        : "t0", "t1", "memory"                  \
    );                                          \
    __builtin_unreachable();                    \
} while(0)


#define CYCLE_COUNTER         (*((volatile uint32_t*)MM_CNT_CYCLE))
#define INSTRUCTION_COUNTER   (*((volatile uint32_t*)MM_CNT_INST))
#define COUNTER_RST           (*((volatile uint32_t*)MM_CNT_RESET))

#define ISR_POLL(share) (1)

#endif // ELSE VIZARD

#endif // MMIO_INTR_COP0_H_
