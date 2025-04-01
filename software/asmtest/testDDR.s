.section    .text
.global     _testDDR

_testDDR:
    lui     $sp, 0x5000
    ori     $sp,     0x1FF0
    li      $s0, 0x10000000
    nop
    lw      $t0, 0x04($s0)
    nop
    sw      $t0, 0x08($s0)
    nop
    lw      $t1, 0x08($s0)
    nop
    nop
    lui     $t4, 0xFFFF
    ori     $t4, 0xFFFF
_delay0:
    lui     $t2, 0xFFFF
    ori     $t2, 0xFFFF
    li      $t3, 1
_delay1:
    nop
    subu    $t2, $t2, $t3
    bgtz    $t2, _delay1
    nop
    subu    $t4, $t4, $t3
    bgtz    $t4, _delay0
_exitDelay:
    nop
    nop
    jr      $31
    nop
    
    j _testDDR

