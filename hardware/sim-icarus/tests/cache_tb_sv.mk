# cache_tb compiled as SystemVerilog (-g2012): regression for the time-0 event workaround in
# ../src/testbench/base_mem.vh (without it the first read miss never completes; see README)
cache_tb_sv.TOP      := CacheTestBench
cache_tb_sv.TB       := $(TBSRC)/CacheTestBench.v
cache_tb_sv.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(DDR2_MODEL)
cache_tb_sv.INCS     := $(TBSRC) $(SRC) $(DDR2_DIR)
cache_tb_sv.YDIRS    := $(SYS_YDIRS)
cache_tb_sv.NEEDS    := xilinx coregen
cache_tb_sv.GROUP    := slow
cache_tb_sv.TIMEOUT  := 1200
cache_tb_sv.PASS_RE  := ^ All tests PASSED
cache_tb_sv.FAIL_RE  := \*FAIL\*|\*\* FAIL|ERROR
cache_tb_sv.QUIET_RE := ^blk_mem_gen_v7_3 collision detected|^  aB:|^LAST:|^TB: Time =
cache_tb_sv.STD      := -g2012
