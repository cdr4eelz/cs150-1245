start CPUDumpMemUARTTestbench
file copy -force ../../../software/dumpmem_c/dumpmem_c.data.mif dmem_blk_ram.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.inst.mif bios_mem.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
log -r /*
run 10000us
