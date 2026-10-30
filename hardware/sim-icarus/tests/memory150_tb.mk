# Original ../src/testbench/Memory150TestBench.v (cachetesttasks.vh: PerformanceCacheExample,
# I$ idle / read-hit tests with concurrent D$ traffic) on Memory150 + MIG + DDR2 model
memory150_tb.TOP      := Memory150TestBench
memory150_tb.TB       := $(TBSRC)/Memory150TestBench.v
memory150_tb.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(DDR2_MODEL)
memory150_tb.INCS     := $(TBSRC) $(SRC) $(DDR2_DIR)
memory150_tb.YDIRS    := $(SYS_YDIRS)
memory150_tb.NEEDS    := xilinx coregen
memory150_tb.GROUP    := slow
memory150_tb.TIMEOUT  := 1200
memory150_tb.PASS_RE  := ^ All tests PASSED
memory150_tb.FAIL_RE  := \*FAIL\*|\*\* FAIL|ERROR
memory150_tb.QUIET_RE := ^blk_mem_gen_v7_3 collision detected|^  aB:|^LAST:|^TB: Time =
