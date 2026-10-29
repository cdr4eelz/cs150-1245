# Self-checking MIPS ISA smoke test for CPUMIPS (run by tests/cpu_isa*.mk via tb/CPU_prog_tb.v).
# Assemble with --defsym DDR=1 to put the load/store scratch area in "DDR" (0x1xxxxxxx),
# where every store stalls the pipeline (cpu_isa_ddr.hex).
# Known-buggy instructions (lb/lh sign extension, jalr rd) live in cpu_known_bugs*.s.
.set noreorder
.set noat
.include "check.inc"
.text
.global _start
_start:
    BEGIN_CHECKS
.ifdef DDR
    lui   $s6, 0x1000
.else
    lui   $s6, 0x5000
.endif
    ori   $s6, $s6, 0x0100          # load/store scratch area

# ---- ALU R-type / I-type --------------------------------------------- checks 0..
    li    $t0, 0x12345678
    li    $t1, 0x0F0F0F0F
    li    $t3, -5
    addu  $t2, $t0, $t1;   CHECK $t2, 0x21436587
    subu  $t2, $t0, $t1;   CHECK $t2, 0x03254769
    add   $t2, $t0, $t1;   CHECK $t2, 0x21436587
    sub   $t2, $t1, $t0;   CHECK $t2, 0xFCDAB897
    and   $t2, $t0, $t1;   CHECK $t2, 0x02040608
    or    $t2, $t0, $t1;   CHECK $t2, 0x1F3F5F7F
    xor   $t2, $t0, $t1;   CHECK $t2, 0x1D3B5977
    nor   $t2, $t0, $t1;   CHECK $t2, 0xE0C0A080
    slt   $t2, $t1, $t0;   CHECK $t2, 1
    slt   $t2, $t3, $t0;   CHECK $t2, 1
    sltu  $t2, $t3, $t0;   CHECK $t2, 0
    slti  $t2, $t3, -4;    CHECK $t2, 1
    slti  $t2, $t3, -5;    CHECK $t2, 0
    sltiu $t2, $t0, 0x7FFF; CHECK $t2, 0
    sltiu $t2, $zero, 1;   CHECK $t2, 1
    sltiu $t2, $t1, -1;    CHECK $t2, 1           # imm sign-extends to 0xFFFFFFFF, compared unsigned
    addiu $t2, $t0, -0x10; CHECK $t2, 0x12345668
    addi  $t2, $t0, 0x10;  CHECK $t2, 0x12345688
    andi  $t2, $t3, 0xFFFF; CHECK $t2, 0x0000FFFB         # zero-extended imm
    ori   $t2, $zero, 0x8001; CHECK $t2, 0x00008001
    xori  $t2, $t0, 0xFFFF; CHECK $t2, 0x1234A987
    lui   $t2, 0xABCD;     CHECK $t2, 0xABCD0000
# ---- shifts
    sll   $t2, $t0, 4;     CHECK $t2, 0x23456780
    srl   $t2, $t3, 28;    CHECK $t2, 0x0000000F
    sra   $t2, $t3, 1;     CHECK $t2, 0xFFFFFFFD
    sra   $t2, $t0, 31;    CHECK $t2, 0
    li    $t4, 8
    sllv  $t2, $t0, $t4;   CHECK $t2, 0x34567800
    srlv  $t2, $t0, $t4;   CHECK $t2, 0x00123456
    srav  $t2, $t3, $t4;   CHECK $t2, 0xFFFFFFFF
    li    $t4, 0x24                                # shift amount uses low 5 bits only (4)
    sllv  $t2, $t0, $t4;   CHECK $t2, 0x23456780
# ---- forwarding / r0
    addiu $t2, $zero, 1
    addu  $t2, $t2, $t2
    addu  $t2, $t2, $t2
    addu  $t2, $t2, $t2;   CHECK $t2, 8
    addiu $zero, $zero, 5; CHECK $zero, 0
    addu  $t2, $zero, $zero; CHECK $t2, 0

# ---- loads / stores (big-endian). Software is built -mips1: one load delay slot
#      (the instruction right after a load must not use its result), hence the nops.
    sw    $t0, 0($s6)
    lw    $t2, 0($s6); nop;     CHECK $t2, 0x12345678   # (MIPS-I load delay slot: the CPU does not forward a load to the next instruction)
    lbu   $t2, 0($s6); nop;     CHECK $t2, 0x12
    lbu   $t2, 3($s6); nop;     CHECK $t2, 0x78
    lhu   $t2, 0($s6); nop;     CHECK $t2, 0x1234
    lhu   $t2, 2($s6); nop;     CHECK $t2, 0x5678
    li    $t5, 0xAB
    sb    $t5, 1($s6)
    lw    $t2, 0($s6); nop;     CHECK $t2, 0x12AB5678
    li    $t5, 0xCDEF
    sh    $t5, 2($s6)
    lw    $t2, 0($s6); nop;     CHECK $t2, 0x12ABCDEF
    lbu   $t2, 1($s6); nop;     CHECK $t2, 0xAB         # lbu stays zero-extended
    lhu   $t2, 2($s6); nop;     CHECK $t2, 0xCDEF
    sw    $t1, 4($s6)
    sw    $t3, 8($s6)
    lw    $t2, 4($s6)
    lw    $t4, 8($s6)
    nop
    addu  $t2, $t2, $t4;   CHECK $t2, 0x0F0F0F0A   # back-to-back loads feeding an add
    lw    $t2, -4($s6); nop;    CHECK $t2, 0             # negative offset (untouched word)

# ---- branches (delay slot always executes)
    li    $t2, 0
    beq   $zero, $zero, 1f
    addiu $t2, $t2, 7                              # delay slot
    addiu $t2, $t2, 100                            # skipped
1:  CHECK $t2, 7
    li    $t2, 0
    bne   $t0, $t1, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # bne taken
    li    $t2, 0
    bne   $t0, $t0, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # bne not taken
    li    $t2, 0
    beq   $t0, $t1, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # beq not taken
    li    $t2, 0
    blez  $t3, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # blez negative
    li    $t2, 0
    blez  $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # blez zero
    li    $t2, 0
    blez  $t0, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # blez positive: not taken
    li    $t2, 0
    bgtz  $t0, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # bgtz positive
    li    $t2, 0
    bgtz  $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # bgtz zero: not taken
    li    $t2, 0
    bltz  $t3, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # bltz negative
    li    $t2, 0
    bltz  $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # bltz zero: not taken
    li    $t2, 0
    bgez  $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0                                    # bgez zero
    li    $t2, 0
    bgez  $t3, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 1                                    # bgez negative: not taken
    li    $t2, 0                                    # branch on a just-computed value (forwarding)
    addiu $t4, $zero, 3
    bne   $t4, $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0
    li    $t2, 0                                    # branch on a just-loaded value
    lw    $t4, 0($s6)
    nop
    bne   $t4, $zero, 1f;  nop;  li $t2, 1
1:  CHECK $t2, 0
    li    $t2, 3                                    # backward branch loop: 3+2+1
    li    $t4, 0
2:  addu  $t4, $t4, $t2
    addiu $t2, $t2, -1
    bgtz  $t2, 2b
    nop
    CHECK $t4, 6

# ---- jumps and links
    li    $t2, 0
    j     1f;  nop;  li $t2, 1
1:  CHECK $t2, 0
    jal   sub_link
    nop
ret_jal:
    CHECK $t5, 0x60000000 + (ret_jal - _start)
    LA_CODE $t4, sub_link
    jalr  $t4                                       # rd = $31 (the form the hardware supports)
    nop
ret_jalr:
    CHECK $t5, 0x60000000 + (ret_jalr - _start)
    LA_CODE $t4, 1f
    li    $t2, 0
    jr    $t4;  nop;  li $t2, 1
1:  CHECK $t2, 0
    bgezal $zero, sub_link
    nop
ret_bgezal:
    CHECK $t5, 0x60000000 + (ret_bgezal - _start)
    li    $ra, 0x1234
    bltzal $zero, sub_link                         # not taken; this CPU does not link (see cpu_known_bugs_bal.s)
    nop
    CHECK $ra, 0x1234

# ---- COP0 registers
    li    $t4, 0x0000FC00                           # all IM bits, IE=0
    mtc0  $t4, $12
    nop
    mfc0  $t2, $12;  nop;  CHECK $t2, 0x0000FC00
    li    $t4, 0x00001234
    mtc0  $t4, $11                                  # Compare
    nop
    mfc0  $t2, $11;  nop;  CHECK $t2, 0x00001234
    mfc0  $t4, $9;   nop                            # Count advances
    nop
    nop
    mfc0  $t2, $9;   nop
    sltu  $t2, $t4, $t2;   CHECK $t2, 1
    mtc0  $zero, $12

    END_CHECKS

# returns with $t5 = link register value at entry
sub_link:
    addu  $t5, $ra, $zero
    jr    $ra
    nop
