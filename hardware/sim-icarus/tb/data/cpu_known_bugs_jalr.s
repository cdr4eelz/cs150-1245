# Known CPU bug (todo_master.txt): jalr rd always links to $31 (ignores rd).
# Expected to FAIL until fixed (tests/cpu_jalr_rd.mk is marked XFAIL).
.set noreorder
.set noat
.include "check.inc"
.text
.global _start
_start:
    BEGIN_CHECKS
    li    $ra, 0x11111111                           # (lui/ori: not a valid code address)
    li    $t6, 0
    LA_CODE $t4, target
    jalr  $t6, $t4                                  # link must go to $t6, not $ra
    nop
ret1:
    CHECK $t6, 0x60000000 + (ret1 - _start)
    CHECK $ra, 0x11111111
    END_CHECKS
target:
    j     ret1                                      # (not jr $t6, so the program finishes either way)
    nop
