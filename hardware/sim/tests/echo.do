start EchoTestbench
file copy -force ../../../software/echo/echo.inst.mif imem_blk_ram.mif
file copy -force ../../../software/echo/echo.data.mif dmem_blk_ram.mif
log -r /*
run 1000us
