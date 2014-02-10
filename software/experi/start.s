.section    .start
.global     _start

.extern _gp 4

_start:
    lui     $v0, 0
    lui     $v1, 0
    lui     $s0, 0
    lui     $s1, 0
    lui     $s2, 0
    lui     $s3, 0
    lui     $s4, 0
    lui     $s5, 0
    lui     $s6, 0
    lui     $s7, 0
    la      $gp, _gp
    lui     $fp, 0
    lui     $sp, 0x1001 # 0000 Fun: pull from LD not hardcode
    lui     $a0, 0
    lui     $a1, 0
    lui     $a2, 0
    lui     $a3, 0
    lui     $ra, 0x4000 # 0000 In case of unexpected return
    j       main
    nop
