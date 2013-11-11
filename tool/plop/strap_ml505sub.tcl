
xload new ml505sub.xmp virtex5 xc5vlx110t ff1136 -1
xset hdl verilog
xset gen_sim_tb true
xset mix_lang_sim true
xset enable_par_timing_error 1
xset parallel_synthesis yes
xset sdk_export_bmm_bit 1

xset hier sub
xset sdk_export_dir ../export/ml505sub
xset ucf_file ml505sub.ucf
file copy -force /home/cc/cs199/fa12/class/cs199-fu/team45/tool/plop/plop.ucf ml505sub.ucf
file copy -force /home/cc/cs199/fa12/class/cs199-fu/team45/tool/plop/plop.mhs ml505sub.mhs
run resync
save proj

run clean
run drc

xget proc_insts
exit
