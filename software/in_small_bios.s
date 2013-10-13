.section    .start
.global     _start

_start:
#   li      $sp, 0x10001000
    jal     main
    jal     main
#   jr      $ra
    j       0x20000000
