start EchoTestbenchDDRCPU
file copy -force ../../../software/echo/echo.inst.mif isr_mem.mif

file copy -force ../../../software/dumpmem/dumpmem.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem/dumpmem.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
add wave EchoDDRCPUTestbench/*
add wave EchoDDRCPUTestbench/mem_arch/*
add wave EchoDDRCPUTestbench/mem_arch/dcache/*
add wave EchoDDRCPUTestbench/mem_arch/icache/*
add wave EchoDDRCPUTestbench/DUT/*
run 10000us
