# PixelFeeder + pixel_fifo under a slow, bursty memory (25% grants, 16 in flight, 16..160 cycles
# latency, 70% beat rate, a 4000-cycle stall every 40000 cycles), 40 MHz CPU vs. 42.5 MHz DVI
# clock and a 60%-ready sink; 2 displayed frames + 2 rows. +fifo_lat=1: see pixel_feeder_fwft.
pixel_feeder_stress.TOP      := PixelFeeder_check_tb
pixel_feeder_stress.TB       := tb/PixelFeeder_check_tb.v
pixel_feeder_stress.INCS     := $(SRC)/gpu
pixel_feeder_stress.YDIRS    := $(SRC)/gpu $(SRC)/base_vid $(SRC)/base_util $(SRC)/core_ip/gpu/pixel_fifo
pixel_feeder_stress.DEFS     := CONSUMER=1 MACROSAFE
pixel_feeder_stress.NEEDS    := xilinx coregen
pixel_feeder_stress.GROUP    := slow
pixel_feeder_stress.TIMEOUT  := 1200
pixel_feeder_stress.PLUSARGS := +fifo_lat=1 +frames=2 +tail_rows=2 +seed=11 +cpu_ps=25000 +dvi_ps=23529 \
                                +grant_pct=25 +qdepth=16 +lat_min=16 +lat_max=160 +beat_pct=70 \
                                +stall_every=40000 +stall_len=4000 +ready_pct=60
pixel_feeder_stress.QUIET_RE := ^  aB:|^LAST:|^WARNING: Behavioral models for independent clock FIFO
