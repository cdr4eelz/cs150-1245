start EchoTestbenchCaches
file copy -force ../../../software/pios/pios.data.mif dmem_blk_ram.mif
file copy -force ../../../software/pios/pios.inst.mif imem_blk_ram.mif
file copy -force ../../../software/pios/pios.inst.mif bios_mem.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
add wave EchoTestbenchCaches/*
add wave EchoTestbenchCaches/mem_arch/*
add wave EchoTestbenchCaches/mem_arch/dcache/*
add wave EchoTestbenchCaches/mem_arch/icache/*
add wave EchoTestbenchCaches/DUT/*
add wave EchoTestbenchCaches/DUT/s_F/*
add wave EchoTestbenchCaches/DUT/s_DX/*
add wave EchoTestbenchCaches/DUT/s_MW/*
add wave EchoTestbenchCaches/DUT/regfile/*
add wave EchoTestbenchCaches/DUT/cop0/*
add wave EchoTestbenchCaches/DUT/memmap_io/*
run 180000us
