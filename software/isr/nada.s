.set noat
.set noreorder

.equiv Count,9
.equiv Compare,11
.equiv Status,12
.equiv Cause,13
.equiv EPC,14

.global     _entry, _isr, _main


.section    .entry, "x"
_entry:
    li  $a0, 0x0000
    j   DISPATCH
    li  $a0, 0x0001
    j   DISPATCH
    li  $a0, 0x0002
    j   DISPATCH
    li  $a0, 0x0003
    j   DISPATCH
    li  $a0, 0x0004
    j   DISPATCH
    li  $a0, 0x0005
    j   DISPATCH
    li  $a0, 0x0006
    j   DISPATCH
    li  $a0, 0x0007
    j   DISPATCH
    nop
    j   DISPATCH


.section    .isr, "x"
_isr:
    mfc0    $k0, $13 #Cause
    mfc0    $k1, $12 #Status
    andi    $k1, $k1, 0xFF00
    and     $k0, $k0, $k1
    andi    $k1, $k0, (1<<15)
    bne     $k1, $0, ISR_TIMER
    andi    $k1, $k0, (1<<14)
    bne     $k1, $0, ISR_RTC
    andi    $k1, $k0, (1<<10)
    bne     $k1, $0, ISR_UART
done:
    j	done
    nop

ISR_TIMER:
ISR_RTC:
ISR_UART:
    j done
    nop


.section    .text

DISPATCH:
    ori     $t0, $a0, 0x0000
    beqz    $t0, DO_ENABLE
    j       DO_DISABLE

DO_ENABLE:
    jr $ra

DO_DISABLE:
    jr $ra
