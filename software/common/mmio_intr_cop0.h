#ifndef COP0_INTR_MMIO_H_
#define COP0_INTR_MMIO_H_

// C HEADER file for Coprocessor, Interrupts & MMIO

// COP0 register names (also c0_sr, c0_cause, etc.)
#define COP0_Count      "$9"    // For inclusion in "asm" sections...
#define COP0_Compare    "$11"   //   as strings.
#define COP0_Status     "$12"
#define COP0_Cause      "$13"
#define COP0_EPC        "$14"


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
#define     IM_POSSIBLE     (0xFC00u)

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
//h014    32'h80000050    PF_FRAME                      Write
    A_PFFrame       =6'h14, // PixelFeeder frame# (ADDR is frame# * 0x0040_0000)
//h015    32'h80000054    GP_FRAME                      Write
    A_GPFrame       =6'h15, // Stored, then "captured" along with GP_CODE on launch
//h016    32'h80000058    GP_CODE                       Write
    A_GPCode        =6'h16, // Write also launches GraphicsProcessor
//h017    32'h8000005C    GPU status                    Read
    A_GPUStatus     =6'h17; // See Memory150 for concatenated signals
*/

// MEMORY-MAPPED IO locations (byte offsets)
#define MMIO_BASE     (0x80000000u)
#define OW_UATX_READY   (0x0000u)
#define OW_UARX_VALID   (0x0004u)
#define OW_UATX_DATA    (0x0008u)
#define  OB_UATX_DATA    (OW_UATX_DATA+3)   //TODO: Eliminate this!
#define OW_UARX_DATA    (0x000Cu)
#define  OB_UARX_DATA    (OW_UARX_DATA+3)   //TODO: Eliminate this!
#define OW_CNT_CYCLE    (0x0010u)
#define OW_CNT_INST     (0x0014u)
#define OW_CNT_RESET    (0x0018u)
#define OW_PF_FRAME     (0x0050u)
#define OW_GP_FRAME     (0x0054u)
#define OW_GP_GCODE     (0x0058u)
#define OW_GP_STATE     (0x005Cu)

// MEMORY-MAPPED IO locations (addresses)
#define MM_UATX_READY   (MMIO_BASE + OW_UATX_READY)
#define MM_UARX_VALID   (MMIO_BASE + OW_UARX_VALID)
#define MM_UATX_DATA    (MMIO_BASE + OW_UATX_DATA)
#define MM_UARX_DATA    (MMIO_BASE + OW_UARX_DATA)
#define     MM_UART_RVA_BIT     (0x0001)
#define     MM_UART_DATA_BYTE   (0x00FF)
#define MM_CNT_CYCLE    (MMIO_BASE + OW_CNT_CYCLE)
#define MM_CNT_INST     (MMIO_BASE + OW_CNT_INST)
#define MM_CNT_RESET    (MMIO_BASE + OW_CNT_RESET)
#define MM_PF_FRAME     (MMIO_BASE + OW_PF_FRAME)
#define MM_GP_FRAME     (MMIO_BASE + OW_GP_FRAME)
#define MM_GP_GCODE     (MMIO_BASE + OW_GP_GCODE)
#define MM_GP_STATE     (MMIO_BASE + OW_GP_STATE)


#define ISR_STATUS(KEEP, SET)                   \
    asm (                                       \
        "li     $t0,%0\n\t"                     \
        "li     $t1,%1\n\t"                     \
        "mfc0   $t2," COP0_Status "\n\t"                    \
        "and    $t2,$t2,$t0\n\t"                \
        "or     $t2,$t2,$t1\n\t"                \
        "mtc0   $t2," COP0_Status "\n\t"                    \
        :                                       \
        : "i" (KEEP), "i" (SET)                 \
        : "t0","t1","t2" )


#endif // COP0_INTR_MMIO_H_
