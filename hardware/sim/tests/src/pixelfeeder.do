start PixelFeederTestbench
file copy -force ../sw/dumpmem_s/dumpmem_s.inst.mif bios_mem.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.data.mif dmem_blk_ram.mif
file copy -force ../sw/isr/nada.mif isr_mem.mif
add wave PixelFeederTestbench/*
add wave PixelFeederTestbench/DUT/*
run 1000ms
