# ASM "HEADER" file for Coprocessor, Interrupts & MMIO

# COP0 register names (also c0_sr, c0_cause, etc.)
.equiv  COP0_Count,     $9
.equiv  COP0_Compare,   $11
.equiv  COP0_Status,    $12
.equiv  COP0_Cause,     $13
.equiv  COP0_EPC,       $14


# COP0 interrupt BIT-offsets (STATUS & CAUSE)
.equiv IB_GLOBAL,   0
.equiv IB_UARX,     10
.equiv IB_UATX,     11
.equiv IB_GPU,      12
.equiv IB_FRAME,    13
.equiv IB_RTC,      14
.equiv IB_TIMER,    15

# COP0 interrupt MASKs (STATUS & CAUSE)
.equiv IM_GLOBAL,   (1 << IB_GLOBAL)
.equiv IM_UARX,     (1 << IB_UARX)
.equiv IM_UATX,     (1 << IB_UATX)
.equiv IM_GPU,      (1 << IB_GPU)
.equiv IM_FRAME,    (1 << IB_FRAME)
.equiv IM_RTC,      (1 << IB_RTC)
.equiv IM_TIMER,    (1 << IB_TIMER)
.equiv  IM_POSSIBLE,    0xFC00


# MEMORY-MAPPED IO locations (offsets)
.equiv  MMIO_BASE,    0x80000000
.equiv  OW_UATX_READY,  0x0000
.equiv  OW_UARX_VALID,  0x0004
.equiv  OW_UATX_DATA,   0x0008
.equiv      OB_UATX_DATA,   (OW_UATX_DATA+3)
.equiv  OW_UARX_DATA,   0x000C
.equiv      OB_UARX_DATA,   (OW_UARX_DATA+3)
.equiv  OW_CNT_CYCLE,   0x0010
.equiv  OW_CNT_INST,    0x0014
.equiv  OW_CNT_RESET,   0x0018
.equiv  OW_PF_FRAME,    0x0050
.equiv  OW_GP_FRAME,    0x0054
.equiv  OW_GP_GCODE,    0x0058
.equiv  OW_GP_STATE,    0x005C

# MEMORY-MAPPED IO locations (addresses)
.equiv  MM_UATX_READY,  (MMIO_BASE + OW_UATX_READY)
.equiv  MM_UARX_VALID,  (MMIO_BASE + OW_UARX_VALID)
.equiv  MM_UATX_DATA,   (MMIO_BASE + OW_UATX_DATA)
.equiv  MM_UARX_DATA,   (MMIO_BASE + OW_UARX_DATA)
.equiv      MM_UART_RVA_BIT,    0x0001
.equiv      MM_UART_DATA_BYTE,  0x00FF
.equiv  MM_CNT_CYCLE,   (MMIO_BASE + OW_CNT_CYCLE)
.equiv  MM_CNT_INST,    (MMIO_BASE + OW_CNT_INST)
.equiv  MM_CNT_RESET,   (MMIO_BASE + OW_CNT_RESET)
.equiv  MM_PF_FRAME,    (MMIO_BASE + OW_PF_FRAME)
.equiv  MM_GP_FRAME,    (MMIO_BASE + OW_GP_FRAME)
.equiv  MM_GP_GCODE,    (MMIO_BASE + OW_GP_GCODE)
.equiv  MM_GP_STATE,    (MMIO_BASE + OW_GP_STATE)
