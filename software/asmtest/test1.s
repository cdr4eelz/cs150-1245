.set noat
.set noreorder

.section    .text
.global     _test1

_test1:

addiu	$s7, $zero, 0x01
addiu	$1, $0, 0x01
addiu	$2, $0, 0x02
addiu	$3, $2, 0x01
addu	$4, $2, $2
addu	$5, $1, $4
addu	$10, $5, $5
j	_test1
nop
