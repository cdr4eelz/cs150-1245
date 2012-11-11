.section    .text
.global     _test3

_test3:

addiu	$s7, $0, 0x03
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
li    $t6, 0xB0D1BEEF
sw    $t0, 0x00($t0)
sw    $t6, 0x04($t0)
sw    $t6, 0x08($t0)
sw    $t6, 0x0C($t0)
sh    $t5, 0x06($t0)
sh    $t4, 0x04($t0)
sb    $t2, 0x08($t0)
sb    $t3, 0x09($t0)
sb    $t4, 0x0A($t0)
sb    $t5, 0x0B($t0)
lw    $t7, 0x04($t0)
lw    $t8, 0x08($t0)
nop
addiu $s7, $s7, 3 # register to hold the test number (in case of failure)
j Done

Other:
addiu $s7, $s7, 255
nop
j Done

Done:
# Write success over serial
nop
nop
j Done

