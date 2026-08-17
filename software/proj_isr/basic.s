.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _dispatch, _isr


# COP0 register names (also c0_sr, c0_cause, etc.)
.equiv Count,       $9
.equiv Compare,     $11
.equiv Status,      $12
.equiv Cause,       $13
.equiv EPC,         $14

# COP0 interrupt BIT-offsets
.equiv B_GLOBAL,    0
.equiv B_UARX,      10
.equiv B_UATX,      11
.equiv B_RTC,       14
.equiv B_TIMER,     15

# COP0 interrupt MASKs
.equiv M_GLOBAL,    (1 << B_GLOBAL)
.equiv M_UARX,      (1 << B_UARX)
.equiv M_UATX,      (1 << B_UATX)
.equiv M_RTC,       (1 << B_RTC)
.equiv M_TIMER,     (1 << B_TIMER)



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
    mfc0    $k0, Cause
    mfc0    $k1, Status
    andi    $k1, $k1, 0xFF00
    and     $k0, $k0, $k1
    andi    $k1, $k0, M_TIMER
    bne     $k1, $zero, ISR_TIMER
    andi    $k1, $k0, M_RTC
    bne     $k1, $zero, ISR_RTC
    andi    $k1, $k0, M_UARX
    bne     $k1, $zero, ISR_UARX
    andi    $k1, $k0, M_UATX
    bne     $k1, $zero, ISR_UATX
#...none active & enabled & implemented...
    j       done_status
    nop

done_cause: #Set $k1 to BITS-TO-KEEP mask for Cause
    mfc0    $k0, Cause
    and     $k0, $k0, $k1
    mtc0    $k0, Cause
done_status:
    mfc0    $k1, Status
    ori     $k1, $k1, M_GLOBAL
    mfc0    $k0, EPC
    jr      $k0
    mtc0    $k1, Status



ISR_TIMER:
    j       done_cause
    addi    $k1, $zero, !M_TIMER

ISR_RTC:
    j       done_cause
    nop
    addi    $k1, $zero, !M_RTC

ISR_UARX:
    j       done_cause
    addi    $k1, $zero, !M_UARX

ISR_UATX:
    j       done_cause
    addi    $k1, $zero, !M_UATX



DO_ENABLE:
    ori     $k1, $zero, (M_UARX | M_GLOBAL)
    jr      $ra
    mtc0    $k1, Status

DO_DISABLE:
    jr      $ra
    mtc0    $zero, Status
