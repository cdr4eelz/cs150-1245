.section    .start
.global     _start

_start:
    li      $sp, 0x50001000
    jal     main
    nop
### jr      $ra
    lui     $ra, 0x4000 #0000
    jr      $ra  ### Jump to bios, since its stack is separate from ours
    nop
