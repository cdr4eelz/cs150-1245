.set noreorder
.set noat
.text
.=0x180
_isr:
    lui   $k1, 0x5000
    mfc0  $k0, $14
    sw    $k0, 0x10($k1)         # breadcrumb: EPC at entry
    ori   $k1, $zero, 0xF7FF     # clear UATX
    mfc0  $k0, $13
    and   $k0, $k0, $k1
    mtc0  $k0, $13
    mfc0  $k1, $12
    ori   $k1, $k1, 1
    mfc0  $k0, $14
    jr    $k0
    mtc0  $k1, $12
