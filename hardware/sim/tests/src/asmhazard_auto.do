//NOTE: Letting assembler handle data read-use hazard fails though branch delay slots are filled.
start EchoTestbench
file copy -force ../sw/asmtest/hazard_auto.mif  imem_blk_ram.mif
file copy -force ../sw/proj_isr/nada.mif        dmem_blk_ram.mif
file copy -force ../sw/proj_isr/nada.mif        bios_mem.mif
file copy -force ../sw/proj_isr/nada.mif        isr_mem.mif
add wave EchoTestbench/*
add wave EchoTestbench/DUT/*
add wave EchoTestbench/DUT/core/*
log -r /*
run 1000us
