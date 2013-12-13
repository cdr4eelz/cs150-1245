.section    .start
.global     _start

_start:
    lui     $v0, 0
    lui     $v1, 0
    lui     $a0, 0
    lui     $a1, 0
    lui     $a2, 0
    lui     $a3, 0
    lui     $s0, 0
    lui     $s1, 0
    lui     $s2, 0
    lui     $s3, 0
    lui     $s4, 0
    lui     $s5, 0
    lui     $s6, 0
    lui     $s7, 0
    lui     $k0, 0
    lui     $k1, 0
    lui     $gp, 0x5000
    li      $fp, 0x50004000
    li      $sp, 0x50004000
    nop
    jal     main
    j       _start
    nop
