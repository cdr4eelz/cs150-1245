start DumpMEMIOTestbench
file copy -force ../../../software/dumpmem/dumpmem.mif dmem_blk_ram.mif
file copy -force ../../../software/dumpmem/tagged.mif imem_blk_ram.mif
log -r /*
run 10000us
