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
    lui     $gp, _gp    # NOTE: Pulled from LD
    lui     $fp, 0x1001 # Fun: passing xtra args above here
    lui     $sp, 0x1001 # 0000 TODO: pull from LD not hardcode
    lui     $ra, 0x4000 # 0000 In case of unexpected return
    j       main
# nop by assembler
