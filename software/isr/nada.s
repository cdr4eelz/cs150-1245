.set noat
.set noreorder

.section    .text
.global     _test0

_test0:

addiu	$s7, $zero, 0x00
addiu	$1, $0, 0x01
addiu	$2, $0, 0x02
addiu	$3, $0, 0x03
addu	$4, $0, $1
addu	$5, $1, $2
addu	$6, $4, $5
nop

Done:
j	Done
nop

