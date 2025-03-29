.section    .text
.global     _testDDR

_testDDR:
    lui     $sp, 0x5000
    ori     $sp,     0x1FF0
    li      $s0, 0x10000000
    lw      $t0, 0x04($s0)
    sw      $t0, 0x08($s0)
    lw      $t1, 0x08($s0)
    nop
    nop
    j _testDDR
    nop

