# gpu/PixelFeeder.v + CoreGen pixel_fifo vs. a memory model (random grants, latency, beat gaps)
# and a random-ready video sink: request addresses/frame wrap/frame select, irq_frame,
# pf_status, every displayed pixel of one frame + 2 rows of the next, FIFO under/overflow
# (tb/PixelFeeder_check_tb.v). allows for the known 1-pixel lag (pixel_feeder_fwft);
# drop it here and in pixel_feeder_dvi/_stress once that is fixed.
pixel_feeder.TOP      := PixelFeeder_check_tb
pixel_feeder.TB       := tb/PixelFeeder_check_tb.v
pixel_feeder.INCS     := $(SRC)/gpu
pixel_feeder.YDIRS    := $(SRC)/gpu $(SRC)/base_vid $(SRC)/base_util $(SRC)/core_ip/gpu/pixel_fifo
pixel_feeder.DEFS     := CONSUMER=1 MACROSAFE
pixel_feeder.NEEDS    := xilinx coregen
pixel_feeder.PLUSARGS := +frames=1 +tail_rows=2 +ready_pct=90 +seed=7
pixel_feeder.QUIET_RE := ^  aB:|^LAST:|^WARNING: Behavioral models for independent clock FIFO
