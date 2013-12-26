.section    .start
.global     _start

_start:
    lui     $sp, 0x1001
    lui     $ra, 0x4000
    j       main
