.set noat
.set noreorder

.section    .text
.global     main

main:

addiu $sp, $sp, -256


halt:
    j halt
    nop
