# FrameFiller + LineEngine -> ScanLineRunner -> DDR write FIFO model vs. reference framebuffer (LITTLEWORDIAN=1)
gpu_raster_lw1.TOP      := GpuRaster_tb
gpu_raster_lw1.TB       := tb/GpuRaster_tb.v
gpu_raster_lw1.SRCS     := $(SRC)/gpu/FrameFiller.v $(SRC)/gpu/LineEngine.v $(SRC)/gpu/ScanLineRunner.v
gpu_raster_lw1.INCS     := $(SRC)/gpu
gpu_raster_lw1.DEFS     := LW=1
gpu_raster_lw1.QUIET_RE := ^\[=LINE=\]|^        : \(|^\[=FILL=\]
