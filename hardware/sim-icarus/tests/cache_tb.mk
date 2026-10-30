# Original ../src/testbench/CacheTestBench.v (dcache write-through, read-miss fill, hits,
# same-index eviction) on Memory150 + MIG + Micron DDR2 model, unmodified bench
cache_tb.TOP      := CacheTestBench
cache_tb.TB       := $(TBSRC)/CacheTestBench.v
cache_tb.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(DDR2_MODEL)
cache_tb.INCS     := $(TBSRC) $(SRC) $(DDR2_DIR)
cache_tb.YDIRS    := $(SYS_YDIRS)
cache_tb.NEEDS    := xilinx coregen
cache_tb.GROUP    := slow
cache_tb.TIMEOUT  := 1200
cache_tb.PASS_RE  := ^ All tests PASSED
cache_tb.FAIL_RE  := \*FAIL\*|\*\* FAIL|ERROR
cache_tb.QUIET_RE := ^blk_mem_gen_v7_3 collision detected|^  aB:|^LAST:|^TB: Time =
