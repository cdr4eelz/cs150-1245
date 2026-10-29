# MIPS32 says BLTZAL/BGEZAL write the link register even when the branch is not taken.
# StageDX.v:105 deliberately suppresses the write for an untaken branch-and-link
# ("Suppress WB on untaken BAL"), so this is expected to FAIL (tests/cpu_bal_untaken_link.mk
# is marked XFAIL). gcc does not emit untaken bltzal/bgezal for normal code, so this is
# low priority; drop the test if the deviation is intended.
.set noreorder
.set noat
.include "check.inc"
.text
.global _start
_start:
    BEGIN_CHECKS
    li    $ra, 0
    bltzal $zero, never                            # not taken, but must still link
    nop
ret1:
    CHECK $ra, 0x60000000 + (ret1 - _start)
    li    $t0, -1
    li    $ra, 0
    bgezal $t0, never                              # not taken
    nop
ret2:
    CHECK $ra, 0x60000000 + (ret2 - _start)
    END_CHECKS
never:
    j     never
    nop
