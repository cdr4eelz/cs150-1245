# PixelFeeder + pixel_fifo driving the real base_vid/DVIData (VESA 800x600@60, 1040x666 raster,
# 40 MHz DVI / 50 MHz CPU as in ml505top.v): video_ready vs. the raster, DVI_DE/H/V timing,
# DVI_D DDR pixel bus, and every pixel of 2 displayed frames + 2 rows (frame wrap twice,
# address and frame# frame selects). +fifo_lat=1: see pixel_feeder_fwft.
pixel_feeder_dvi.TOP      := PixelFeeder_check_tb
pixel_feeder_dvi.TB       := tb/PixelFeeder_check_tb.v
pixel_feeder_dvi.INCS     := $(SRC)/gpu
pixel_feeder_dvi.YDIRS    := $(SRC)/gpu $(SRC)/base_vid $(SRC)/base_util $(SRC)/core_ip/gpu/pixel_fifo
pixel_feeder_dvi.DEFS     := CONSUMER=0 MACROSAFE
pixel_feeder_dvi.NEEDS    := xilinx coregen
pixel_feeder_dvi.GROUP    := slow
pixel_feeder_dvi.TIMEOUT  := 1200
pixel_feeder_dvi.PLUSARGS := +fifo_lat=1 +frames=2 +tail_rows=2 +seed=3
pixel_feeder_dvi.QUIET_RE := ^  aB:|^LAST:|^WARNING: Behavioral models for independent clock FIFO
