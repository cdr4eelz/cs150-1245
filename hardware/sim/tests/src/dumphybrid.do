start EchoTestbenchHybrid
file copy -force ../sw/dumpmem_s/dumpmem_s.inst.mif bios_mem.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../sw/dumpmem_i/dumpmem_i.data.mif dmem_blk_ram.mif
file copy -force ../sw/proj_isr/nada.mif isr_mem.mif
add wave EchoTestbenchHybrid/*
add wave EchoTestbenchHybrid/mem_arch/*
add wave EchoTestbenchHybrid/mem_arch/dcache/*
add wave EchoTestbenchHybrid/mem_arch/icache/*
add wave EchoTestbenchHybrid/DUT/*
add wave EchoTestbenchHybrid/DUT/membank/*
add wave EchoTestbenchHybrid/DUT/membank/memmap/*
add wave EchoTestbenchHybrid/DUT/cpu/cop0/*
add wave EchoTestbenchHybrid/DUT/cpu/regfile/*
add wave EchoTestbenchHybrid/DUT/cpu/s_F/*
add wave EchoTestbenchHybrid/DUT/cpu/s_DX/*
add wave EchoTestbenchHybrid/DUT/cpu/s_MW/*
run 20000us
