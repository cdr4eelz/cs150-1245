start EchoTestbench
file copy -force ../sw/zeros/nada.mif bios_mem.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.data.mif dmem_blk_ram.mif
file copy -force ../sw/isr/nada.mif isr_mem.mif
log -r /*
run 2000us
