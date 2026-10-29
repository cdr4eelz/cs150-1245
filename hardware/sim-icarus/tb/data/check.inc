# Shared by the CPU program tests (tb/CPU_prog_tb.v).
# CHECK reg, expected: append the pair (actual, expected) to the results table at $s7
# and bump $s7. Uses $t9 and $s7 only. The testbench compares the pairs after the
# program stores DONE_MAGIC to 0x50000000 and the pair count to 0x50000004.
# Check numbers printed by the testbench count CHECKs from 0 in program order.
.equiv RESULTS,    0x50000400
.equiv DONE_MAGIC, 0x600DC0DE

.macro CHECK r, exp
    sw    \r, 0($s7)
    li    $t9, \exp
    sw    $t9, 4($s7)
    addiu $s7, $s7, 8
.endm

.macro BEGIN_CHECKS
    lui   $s7, %hi(RESULTS)
    ori   $s7, $s7, %lo(RESULTS)
.endm

.macro END_CHECKS
    lui   $t9, 0x5000
    lui   $t8, %hi(RESULTS)
    ori   $t8, $t8, %lo(RESULTS)
    subu  $t8, $s7, $t8
    srl   $t8, $t8, 3
    sw    $t8, 4($t9)              # number of CHECKs
    li    $t8, DONE_MAGIC
    sw    $t8, 0($t9)              # done
99: j     99b
    nop
.endm

# Run-time address of a code label (code runs at 0x60000000; offset must be < 64K).
# (Explicit lui/ori: `li r, 0x60000000 + (fwd_label - _start)` silently drops the
#  upper half when the label is a forward reference.)
.macro LA_CODE r, label
    lui   \r, 0x6000
    ori   \r, \r, (\label - _start)
.endm
