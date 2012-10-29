.set noat

.section    .text
.global     _test1

_test1:

addiu	$1, $0, 0x01
addiu	$2, $0, 0x02
addiu	$3, $0, 0x03
addu	$4, $0, $1
addu	$5, $1, $2
addu	$6, $4, $5

Done:
# Write success over serial
