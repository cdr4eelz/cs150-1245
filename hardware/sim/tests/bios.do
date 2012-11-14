start EchoTestbench
file copy -force ../../../software/bios150v3/bios150v3.mif imem_blk_ram.mif
file copy -force ../../../software/bios150v3/bios150v3.mif dmem_blk_ram.mif
log -r /*
run 10000us
