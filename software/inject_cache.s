.section    .start
.global     _start

_start:
    li      $ra, 0x40000000
    nop
    j       main            //This is "j" for jump, calle returns to BIOS
    nop
    li      $ra, 0x40000000
    nop
    jr      $ra
    nop

