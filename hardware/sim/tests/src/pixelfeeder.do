start PixelFeederTestbench
file copy -force ../../../software/dumpmem_s/dumpmem_s.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.data.mif dmem_blk_ram.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
add wave PixelFeederTestbench/*
add wave PixelFeederTestbench/DUT/*
run 1000ms
