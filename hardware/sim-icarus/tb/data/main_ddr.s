.set noreorder
.set noat
.text
    ori   $t0, $zero, 0x0801     # IM_UATX | IE
    mtc0  $t0, $12
    lui   $s0, 0x1000            # "DDR" (cached, stalls after store)
    lui   $s1, 0x5000            # BRAM scratch
    ori   $s2, $zero, 0
loop:
    sw    $s2, 0($s0)            # DDR store => stall next cycle
    addiu $s2, $s2, 1
    sw    $s2, 0x100($s1)        # progress counter
    j     loop
    nop
