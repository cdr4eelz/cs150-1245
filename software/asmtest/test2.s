.set noreorder

.section    .text
.global     _test2

_test2:

addiu $s7, $zero, 0x2
# Test 2

li $s0, 0x00000020
addiu $t0, $0, 0x20
addiu $s8, $s7, 1 # register to hold the test number (in case of failure)
bne $t0, $s0, Error
nop
j Done
nop

Error:
# Perhaps write the test number over serial
addu $t1, $0, $s7
nop
j Error
nop

Done:
# Write success over serial
addu $t2, $s7, $0
nop
j Done
nop

