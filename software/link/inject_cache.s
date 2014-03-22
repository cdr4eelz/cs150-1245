.section    .start
.global     _start

.extern _gp

_start:
    la      $gp, _gp
    la      $sp, 0x10003000
    lui     $ra, 0x4000 #0000
    j       main
