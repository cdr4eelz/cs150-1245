.set noat
.set noreorder

# The location of these entries is forced below
.global     _entry, _dispatch, _isr


# COP0 register names (also c0_sr, c0_cause, etc.)
.equiv Count,$9
.equiv Compare,$11
.equiv Status,$12
.equiv Cause,$13
.equiv EPC,$14


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
    jr      $ra


# ISR starts at 0xC000180
.=0x0180
_isr:
    mfc0    $k0, Cause
    mfc0    $k1, Status
    andi    $k1, $k1, 0xFF00
    and     $k0, $k0, $k1
    andi    $k1, $k0, (1<<15)
    bne     $k1, $0, ISR_TIMER
    andi    $k1, $k0, (1<<14)
    bne     $k1, $0, ISR_RTC
    andi    $k1, $k0, (1<<10)
    bne     $k1, $0, ISR_UART
#...fallthrough...
done:
    mfc0    $k1, Status
    ori     $k1, $k1, 1
    mfc0    $k0, EPC
    jr      $k0
    mtc0    $k1, Status


ISR_TIMER:
    j       done
    nop

ISR_RTC:
    j       done
    nop

ISR_UART:
    j       done
    nop


DO_ENABLE:
    ori     $k1, $zero, (1<<10)
    ori     $k1, $k1, 1
    jr      $ra
    mtc0    $k1, Status

DO_DISABLE:
    jr      $ra
    mtc0    $0, Status
