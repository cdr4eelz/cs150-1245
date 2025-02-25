.section    .start
.global     _start

_start:
    li      $sp, 0x50001000
    jal     main
    nop
    jr      $ra
    nop
