start EchoTestbenchHybrid
file copy -force ../../../software/echo/echo.inst.mif isr_mem.mif

#file copy -force ../../../software/dumpmem/dumpmem.inst.mif bios_mem.mif
#file copy -force ../../../software/dumpmem/dumpmem.inst.mif imem_blk_ram.mif
#file copy -force ../../../software/dumpmem/dumpmem.data.mif dmem_blk_ram.mif
file copy -force ../../../software/dumpmem_s/dumpmem.inst.mif bios_mem.mif
file copy -force ../../../software/dumpmem_s/dumpmem.inst.mif imem_blk_ram.mif
file copy -force ../../../software/dumpmem_s/dumpmem.data.mif dmem_blk_ram.mif
#file copy -force ../../../software/echo/echo.inst.mif bios_mem.mif
#file copy -force ../../../software/echo/echo.inst.mif imem_blk_ram.mif
#file copy -force ../../../software/echo/echo.data.mif dmem_blk_ram.mif
log -r /*
run 4832us
