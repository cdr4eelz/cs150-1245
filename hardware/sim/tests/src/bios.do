start EchoTestbenchHybrid
file copy -force ../sw/bios150v3/bios150v3.data.mif dmem_blk_ram.mif
file copy -force ../sw/bios150v3/bios150v3.inst.mif imem_blk_ram.mif
file copy -force ../sw/bios150v3/bios150v3.inst.mif bios_mem.mif
file copy -force ../sw/proj_isr/nada.mif isr_mem.mif
add wave EchoTestbenchHybrid/*
add wave EchoTestbenchHybrid/mem_arch/*
add wave EchoTestbenchHybrid/mem_arch/dcache/*
add wave EchoTestbenchHybrid/mem_arch/icache/*
add wave EchoTestbenchHybrid/DUT/*
add wave EchoTestbenchHybrid/DUT/bank/*
add wave EchoTestbenchHybrid/DUT/bank/memmap/*
add wave EchoTestbenchHybrid/DUT/cop0/*
add wave EchoTestbenchHybrid/DUT/regfile/*
add wave EchoTestbenchHybrid/DUT/core/s_F/*
add wave EchoTestbenchHybrid/DUT/core/s_DX/*
add wave EchoTestbenchHybrid/DUT/core/s_MW/*
run 50000us
