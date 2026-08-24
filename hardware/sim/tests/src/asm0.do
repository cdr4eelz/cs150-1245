start EchoTestbench
file copy -force ../sw/asmtest/test0.data.mif dmem_blk_ram.mif
file copy -force ../sw/asmtest/test0.mif      imem_blk_ram.mif
file copy -force ../sw/asmtest/test0.mif      bios_mem.mif
file copy -force ../sw/proj_isr/nada.mif isr_mem.mif
log -r /*
run 1000us
