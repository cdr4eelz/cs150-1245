start ASMTestbench
file copy -force ../../../software/asmtest/test0.mif      imem_blk_ram.mif
file copy -force ../../../software/asmtest/test0.data.mif dmem_blk_ram.mif
log -r /*
run 1000us
