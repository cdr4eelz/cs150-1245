.section    .text
.global     _test4

_test4:

addiu $s7, $0, 0x0
# Test 1

li $s0, 0x00000020
addiu $t0, $0, 0x20
addiu $s7, $s7, 1 # register to hold the test number (in case of failure)
bne $t0, $s0, Error
addiu $s8, $s7, 14
addiu $s8, $s8, 1
subu $t0, $s7, $s8
bgtz $t0, Error
subu $t0, $s8, $s7
bltz $t0, Error
beq $t0, $0, Error
bgtz $t0, Done
addiu $t0, $0, 9

Error:
# Perhaps write the test number over serial
addu $t1, $0, $0
j Error

Done:
# Write success over serial
nop
nop
j Done

