.set noat
.set noreorder

.section    .text
.global     _hazard

.include "mmio_intr_cop0.s.inc"


_hazard:
	la	$t2, 0x50000000
	li	$t1, 0xFEEDBEEF
	sw	$t1, 0($t2)
	li	$t0, 0
	lw	$t0, 0($t2)
	###nop	# THIS is required since CPU doesn't handle data-hazard
	beq	$t0, $zero, IS_ZERO
	nop
NOT_ZERO:
	ori	$t1, $zero, '-'
	b	SEND_CH
	nop
IS_ZERO:
	ori	$t1, $zero, '='
	#Fallthrough
SEND_CH:
	la	$t2, MMIO_BASE
	lw	$t0, OW_UATX_READY($t2)
	nop
	beq	$t0, $zero, SEND_CH
	nop
	sw	$t1, OW_UATX_DATA($t2)
FOREVER:
	nop
# 	b FOREVER
 	b SEND_CH
	nop

