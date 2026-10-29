# Memory150 + Cache + MIG + Micron DDR2 model (patched copy, see scripts/patch-ddr2-model.sh):
# write-through, fills, hits, byte masks, eviction, random vs shadow (tb/Memory150_ddr_tb.v)
memory150_ddr.TOP     := Memory150_ddr_tb
memory150_ddr.TB      := tb/Memory150_ddr_tb.v
memory150_ddr.SRCS    := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(DDR2_MODEL)
memory150_ddr.INCS    := $(TBSRC) $(SRC) $(DDR2_DIR)
memory150_ddr.YDIRS   := $(SYS_YDIRS)
memory150_ddr.NEEDS   := xilinx
memory150_ddr.GROUP   := slow
memory150_ddr.TIMEOUT := 1200
memory150_ddr.QUIET_RE := ^blk_mem_gen_v7_3 collision detected
