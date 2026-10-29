.set noreorder
.set noat
.text
    ori   $t0, $zero, 0x0801
    mtc0  $t0, $12
    lui   $s1, 0x5000
    ori   $s2, $zero, 0
loop:
    addiu $s2, $s2, 1
    sw    $s2, 0x100($s1)        # progress counter
    mfc0  $t2, $12               # ISR_STATUS-style RMW of Status (keep all)
    or    $t2, $t2, $zero
    mtc0  $t2, $12
    j     loop
    nop
