start EchoTestbench
file copy -force ../../../software/bios150v3/bios150v3.data.mif dmem_blk_ram.mif
file copy -force ../../../software/bios150v3/bios150v3.inst.mif imem_blk_ram.mif
file copy -force ../../../software/bios150v3/bios150v3.inst.mif bios_mem.mif
file copy -force ../../../software/bios150v3/bios150v3.inst.mif isr_mem.mif
log -r /*
run 1000us
