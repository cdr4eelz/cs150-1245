start EchoTestbenchHybrid
file copy -force ../sw/bios150v3/bios150v3.data.mif dmem_blk_ram.mif
file copy -force ../sw/bios150v3/bios150v3.inst.mif imem_blk_ram.mif
file copy -force ../sw/bios150v3/bios150v3.inst.mif bios_mem.mif
file copy -force ../sw/isr/nada.mif isr_mem.mif
add wave EchoTestbenchCaches/*
add wave EchoTestbenchCaches/mem_arch/*
add wave EchoTestbenchCaches/mem_arch/dcache/*
add wave EchoTestbenchCaches/mem_arch/icache/*
add wave EchoTestbenchCaches/DUT/*
add wave EchoTestbenchCaches/DUT/regfile/*
add wave EchoTestbenchCaches/DUT/s_F/*
add wave EchoTestbenchCaches/DUT/s_DX/*
add wave EchoTestbenchCaches/DUT/s_MW/*
run 50000us
