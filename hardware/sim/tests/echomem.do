start EchoMemTestbench
file copy -force ../../../software/echomem/echomem.mif dmem_blk_ram.mif
log -r /*
run 10000us
