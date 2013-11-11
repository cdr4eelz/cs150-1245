#!/bin/bash -beuxE

PLAT_B="plop"
PLAT_N="ml505sub"
PLAT_T="virtex5 xc5vlx110t ff1136 -1" #TARGET: Family Device Package SpeedGrade
D="$PWD"

# MHS is where the beef is so its easy to just roll a fresh xps project.

STRAP="strap_${PLAT_N}.tcl"
cat > "${STRAP}" <<EOM

xload new ${PLAT_N}.xmp ${PLAT_T}
xset hdl verilog
xset gen_sim_tb true
xset mix_lang_sim true
xset enable_par_timing_error 1
xset parallel_synthesis yes
xset sdk_export_bmm_bit 1

xset hier sub
xset sdk_export_dir ../export/${PLAT_N}
xset ucf_file ${PLAT_N}.ucf
file copy -force ${D}/${PLAT_B}.ucf ${PLAT_N}.ucf
file copy -force ${D}/${PLAT_B}.mhs ${PLAT_N}.mhs
run resync
save proj

run clean
run drc

xget proc_insts
exit
EOM

