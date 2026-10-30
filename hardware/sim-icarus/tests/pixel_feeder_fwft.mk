# Regression for the old 1-pixel lag: PixelFeeder treats pixel_fifo as first-word-fall-through
# (gpu/PixelFeeder.v: video = dout, rd_en = video_ready), so pixel_fifo.xco must be generated as
# First_Word_Fall_Through (fixed in de6237a). With a Standard_FIFO every pixel showed one position
# late (x=0 showed x=799 of the row above). Strict check of the first FIFO-fed row.
pixel_feeder_fwft.TOP      := PixelFeeder_check_tb
pixel_feeder_fwft.TB       := tb/PixelFeeder_check_tb.v
pixel_feeder_fwft.INCS     := $(SRC)/gpu
pixel_feeder_fwft.YDIRS    := $(SRC)/gpu $(SRC)/base_vid $(SRC)/base_util $(SRC)/core_ip/gpu/pixel_fifo
pixel_feeder_fwft.DEFS     := CONSUMER=1 MACROSAFE
pixel_feeder_fwft.NEEDS    := xilinx coregen
pixel_feeder_fwft.QUIET_RE := ^  aB:|^LAST:|^WARNING: Behavioral models for independent clock FIFO
pixel_feeder_fwft.PLUSARGS := +frames=0 +tail_rows=1 +ready_pct=100
