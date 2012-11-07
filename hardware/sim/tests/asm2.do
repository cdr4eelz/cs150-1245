start ASMTestbench
file copy -force ../../../software/asmtest/test2.mif imem_blk_ram.mif
file copy -force ../../../software/asmtest/test0.mif dmem_blk_ram.mif
log -r /*
run 10000us
