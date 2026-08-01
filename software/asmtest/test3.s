.section    .text
.global     _test3

### $t4 thru $t7 are not defined in old GAS ###
### Changed them to $12 thru $15 instead    ###

_test3:

addi  $s7, $0, 0x03
addiu $t0, $0, 0x0
addiu $t1, $t0, 1
addiu $t2, $t1, 1
addiu $t3, $t2, 1
addiu $12, $t3, 1     # $t4=$12
addiu $13, $12, 1     # $t4=$12 & $t5=$13
addu  $s0, $13, $13   # $t5=$13
addu  $s1, $t1, $s0
addu  $s2, $t2, $s1
addu  $s3, $t3, $s2
addu  $s4, $12, $s3   # $t4=$12
addu  $s5, $13, $s4   # $t5=$13
addu  $s6, $s5, $s5
addu  $s7, $s6, $s5
li    $s0, 0x10000000
li    $14, 0xB0D1BEEF # $t6=$14
sw    $t0, 0x00($s0)
sw    $14, 0x04($s0)  # $t6=$14
sw    $14, 0x08($s0)  # $t6=$14
sw    $14, 0x0C($s0)  # $t6=$14
sh    $12, 0x04($s0)  # $t4=$12
sh    $13, 0x06($s0)  # $t5=$13
sb    $t2, 0x08($s0)
sb    $t3, 0x09($s0)
sb    $12, 0x0A($s0)  # $t4=$12
sb    $13, 0x0B($s0)  # st5=$13
lw    $t0, 0x04($s0)
lw    $t1, 0x08($s0)
lh    $t2, 0x04($s0)
lh    $t3, 0x06($s0)
lb    $12, 0x08($s0)  # $t4=$12
lb    $13, 0x09($s0)  # $t5=$13
lb    $14, 0x0A($s0)  # $t6=$14
lb    $15, 0x0B($s0)  # $t7=$15
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

