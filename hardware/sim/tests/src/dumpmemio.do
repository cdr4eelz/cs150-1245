start DumpMEMIOTestbench
file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
file copy -force ../../../software/dumpmem/dumpmem.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem/dumpmem.inst.mif bios_mem.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
log -r /*
run 1000us
