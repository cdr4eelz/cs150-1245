.section    .text
.global     _test2

_test2:

addiu $t0, $0, 0x0
addiu $t1, $t0, 1
addiu $t2, $t1, 1
addiu $t3, $t2, 1
addiu $t4, $t3, 1
addiu $t5, $t4, 1
addu  $s0, $t5, $t5
addu  $s1, $t1, $s0
addu  $s2, $t2, $s1
addu  $s3, $t3, $s2
addu  $s4, $t4, $s3
addu  $s5, $t5, $s4
addu  $s6, $s5, $s5
addu  $s7, $s6, $s5
nop
addiu $s7, $s7, 1 # register to hold the test number (in case of failure)
j Done

Done:
# Write success over serial
nop
nop
j Done

