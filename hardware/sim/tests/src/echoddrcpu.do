start EchoTestbenchDDRCPU
file copy -force ../../../software/echo/echo.inst.mif isr_mem.mif

file copy -force ../../../software/dumpmem/dumpmem.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem/dumpmem.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
add wave EchoTestbenchDDRCPU/*
add wave EchoTestbenchDDRCPU/mem_arch/*
add wave EchoTestbenchDDRCPU/mem_arch/dcache/*
add wave EchoTestbenchDDRCPU/mem_arch/icache/*
add wave EchoTestbenchDDRCPU/DUT/*
run 10000us
