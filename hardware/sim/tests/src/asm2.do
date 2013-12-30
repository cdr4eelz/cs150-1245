start ASMTestbench
file copy -force ../../../software/asmtest/test2.data.mif dmem_blk_ram.mif
file copy -force ../../../software/asmtest/test2.mif      imem_blk_ram.mif
file copy -force ../../../software/asmtest/test2.mif      bios_mem.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
log -r /*
run 1000us
