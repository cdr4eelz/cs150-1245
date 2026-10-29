# Known CPU bug (todo_master.txt): lb/lh do not sign-extend (behave like lbu/lhu).
# Expected to FAIL until fixed (tests/cpu_lb_lh_sign.mk is marked XFAIL).
.set noreorder
.set noat
.include "check.inc"
.text
.global _start
_start:
    BEGIN_CHECKS
    lui   $s6, 0x5000
    ori   $s6, $s6, 0x0100
    li    $t0, 0x80FF7F01
    sw    $t0, 0($s6)
    lb    $t2, 0($s6); nop;  CHECK $t2, 0xFFFFFF80
    lb    $t2, 1($s6); nop;  CHECK $t2, 0xFFFFFFFF
    lb    $t2, 2($s6); nop;  CHECK $t2, 0x0000007F
    lb    $t2, 3($s6); nop;  CHECK $t2, 0x00000001
    lh    $t2, 0($s6); nop;  CHECK $t2, 0xFFFF80FF
    lh    $t2, 2($s6); nop;  CHECK $t2, 0x00007F01
    lbu   $t2, 0($s6); nop;  CHECK $t2, 0x00000080
    lhu   $t2, 0($s6); nop;  CHECK $t2, 0x000080FF
    END_CHECKS
