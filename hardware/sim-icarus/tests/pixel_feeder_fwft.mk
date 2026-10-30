# Known bug (XFAIL): PixelFeeder treats pixel_fifo as first-word-fall-through ("NOTE:
# First-word-fallthrough" in gpu/PixelFeeder.v: video = dout, rd_en = video_ready), but
# core_ip/gpu/pixel_fifo/pixel_fifo.xco generates a Standard_FIFO (C_PRELOAD_LATENCY=1), whose
# dout shows a word one clock after rd_en. Every pixel the DVI takes is therefore the previous
# FIFO word: the picture is shifted right by one pixel (x=0 shows x=799 of the row above, the
# very first pixel shows the FIFO reset value 0). Strict check of the first FIFO-fed row.
pixel_feeder_fwft.TOP      := PixelFeeder_check_tb
pixel_feeder_fwft.TB       := tb/PixelFeeder_check_tb.v
pixel_feeder_fwft.INCS     := $(SRC)/gpu
pixel_feeder_fwft.YDIRS    := $(SRC)/gpu $(SRC)/base_vid $(SRC)/base_util $(SRC)/core_ip/gpu/pixel_fifo
pixel_feeder_fwft.DEFS     := CONSUMER=1 MACROSAFE
pixel_feeder_fwft.NEEDS    := xilinx coregen
pixel_feeder_fwft.QUIET_RE := ^  aB:|^LAST:|^WARNING: Behavioral models for independent clock FIFO
pixel_feeder_fwft.PLUSARGS := +frames=0 +tail_rows=1 +ready_pct=100
pixel_feeder_fwft.XFAIL    := PixelFeeder shows each pixel one position late (Standard_FIFO pixel_fifo used as FWFT); remove once fixed
