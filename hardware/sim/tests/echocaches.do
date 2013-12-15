start EchoTestbenchCaches
file copy -force ../../../software/dumpmem/dumpmem.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem/dumpmem.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
#file copy -force ../../../software/dumpmem_s/dumpmem.inst.mif bios_mem.mif
#file copy -force ../../../software/dumpmem_s/dumpmem.inst.mif imem_blk_ram.mif
#file copy -force ../../../software/dumpmem_s/dumpmem.data.mif dmem_blk_ram.mif
#file copy -force ../../../software/bios150v3/bios150v3.inst.mif bios_mem.mif
#file copy -force ../../../software/bios150v3/bios150v3.inst.mif imem_blk_ram.mif
#file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
add wave EchoTestbenchCaches/*
add wave EchoTestbenchCaches/mem_arch/*
add wave EchoTestbenchCaches/mem_arch/dcache/*
add wave EchoTestbenchCaches/mem_arch/icache/*
add wave EchoTestbenchCaches/DUT/dpath/*
add wave EchoTestbenchCaches/DUT/ctrl/*
add wave EchoTestbenchCaches/DUT/dpath/ua/*
add wave EchoTestbenchCaches/DUT/dpath/regfile/*
run 10000us
