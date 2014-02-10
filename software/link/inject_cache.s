.section    .start
.global     _start

.extern _gp

_start:
    la      $gp, _gp
    lui     $sp, 0x1001
    lui     $ra, 0x4000
    j       main
