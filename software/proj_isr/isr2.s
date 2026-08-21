.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _isr

.include "mmio_intr_cop0.s.inc"

# SHARED memory locations
#struct SM_DATA {
#    uint32_t stash0, stash1;
#    uint32_t buff_size;
#    uint32_t buff_offset;
#    int8_t buff_data[K_BUFSIZEB];
#};
.equiv  SM_BASE,    0x50000000  #Some agreed upon spot in memory
.equiv  SM_stash0,      SM_BASE + 0x0000
.equiv  SM_stash1,      SM_BASE + 0x0004
.equiv  SM_buff_size,   SM_BASE + 0x0008
.equiv  SM_buff_offset, SM_BASE + 0x000C
.equiv  SM_buff_data,   SM_BASE + 0x0010


# A simple jump-table for JALing in from BIOS
.=0x0000
_entry:
    j       DISPATCH
    li      $a0, 0x0000
.=0x0010
    j       DISPATCH
    li      $a0, 0x0001
.=0x0020
    j       DISPATCH
    li      $a0, 0x0002
.=0x0030
    j       DISPATCH
    li      $a0, 0x0003
.=0x0040
    j       DISPATCH
    li      $a0, 0x0004
.=0x0050
    j       DISPATCH
    li      $a0, 0x0005
.=0x0060
    j       DISPATCH
    li      $a0, 0x0006
.=0x0070
    j       DISPATCH
    li      $a0, 0x0007
.=0x0080
    j       DISPATCH
    li      $a0, 0x0008
.=0x0090
    j       DISPATCH
    li      $a0, 0x0009

# The actual dispatch based on $a0 code (keep smaller than 0x80 bytes!)
.=0x0100
DISPATCH:
    ori     $t0, $zero, 0x0000
    beq     $t0, $a0, DO_ENABLE
    ori     $t0, $zero, 0x0001
    beq     $t0, $a0, DO_DISABLE
    ori     $t0, $zero, 0x0002
    jr      $ra
    nop


# ISR starts at 0xC000180
.=0x0180
_isr:
    mfc0    $k0, COP0_Cause
    mfc0    $k1, COP0_Status
    andi    $k1, $k1, 0xFF00
    and     $k0, $k0, $k1
    andi    $k1, $k0, IM_TIMER
    bne     $k1, $zero, ISR_TIMER
    nop
    andi    $k1, $k0, IM_RTC
    bne     $k1, $zero, ISR_RTC
    nop
    andi    $k1, $k0, IM_UARX
    bne     $k1, $zero, ISR_UARX
    nop
    andi    $k1, $k0, IM_UATX
    bne     $k1, $zero, ISR_UATX
    nop
#...none active & enabled & implemented...
    j       done_status
    nop

done_cause: #Set $k1 to BITS-TO-KEEP mask for Cause
    mfc0    $k0, COP0_Cause
    and     $k0, $k0, $k1
    mtc0    $k0, COP0_Cause
done_status:
    mfc0    $k1, COP0_Status
    ori     $k1, $k1, IM_GLOBAL
    mfc0    $k0, COP0_EPC
    jr      $k0
    mtc0    $k1, COP0_Status



ISR_TIMER:
    j       done_cause
    addi    $k1, $zero, !IM_TIMER

ISR_RTC:
    j       done_cause
    addi    $k1, $zero, !IM_RTC

ISR_UARX:
    j       done_cause
    addi    $k1, $zero, !IM_UARX

ISR_UATX:
###TEMP: Stash state stuff into stashes
    mfc0    $k0, COP0_Cause
    la      $k1, SM_stash0
    sw      $k0, 0($k1)  # Store Cause
    mfc0    $k0, COP0_Status
    la      $k1, SM_stash1
    sw      $k0, 0($k1)  # Store Status

###TEMP: Try send char DURING interrupt
    ori     $k0, $zero, '#'
    la      $k1, MM_UATX_DATA
    sw      $k0, 0($k1)  #Send character

#TEMP: Disable IM_UATX interrupt
done_temp:
    mfc0    $k1, COP0_Status
    andi    $k1, $k1, !IM_UATX
    mtc0    $k1, COP0_Status
#Fallthrough to standard ISR return here...
    j       done_cause
    addi    $k1, $zero, !IM_UATX



DO_ENABLE:
    ori     $k1, $zero, (IM_UARX | IM_GLOBAL)
    jr      $ra
    mtc0    $k1, COP0_Status

DO_DISABLE:
    jr      $ra
    mtc0    $zero, COP0_Status
