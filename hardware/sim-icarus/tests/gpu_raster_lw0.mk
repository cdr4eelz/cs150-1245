# FrameFiller + LineEngine -> ScanLineRunner -> DDR write FIFO model vs. reference framebuffer (LITTLEWORDIAN=0)
gpu_raster_lw0.TOP      := GpuRaster_tb
gpu_raster_lw0.TB       := tb/GpuRaster_tb.v
gpu_raster_lw0.SRCS     := $(SRC)/gpu/FrameFiller.v $(SRC)/gpu/LineEngine.v $(SRC)/gpu/ScanLineRunner.v
gpu_raster_lw0.INCS     := $(SRC)/gpu
gpu_raster_lw0.DEFS     := LW=0
gpu_raster_lw0.QUIET_RE := ^\[=LINE=\]|^        : \(|^\[=FILL=\]
