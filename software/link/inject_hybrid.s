.section    .start
.global     _start

_start:
    li      $sp, 0x50003000
    jal     main
    nop

