start CPUEchoDDRTestbench
file copy -force ../../../software/dumpmem_c/dumpmem_c.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem_i/dumpmem_i.data.mif dmem_blk_ram.mif
file copy -force ../../../software/isr/nada.mif isr_mem.mif
add wave CPUEchoDDRTestbench/*
add wave CPUEchoDDRTestbench/mem_arch/*
add wave CPUEchoDDRTestbench/mem_arch/dcache/*
add wave CPUEchoDDRTestbench/mem_arch/icache/*
add wave CPUEchoDDRTestbench/DUT/*
run 10000us
