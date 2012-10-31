start DumpMemTestbench
file copy -force ../../../software/dumpmem/dumpmem.mif dmem_blk_ram.mif
log -r /*
run 10000us
