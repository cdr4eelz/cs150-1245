.section    .start_imem
.global     _start_imem

_start_imem:
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

    lui     $gp, %hi(_gp)
    addiu   $gp, $gp, %lo(_gp)
    lui     $fp, %hi(_fp)
    addiu   $fp, $fp, %lo(_fp)
    lui     $sp, %hi(_sp)
    addiu   $sp, $sp, %lo(_sp)

    lui     $ra, 0x4000     # If ever "returns", launch BIOS fresh
    j       main_imem
    nop
