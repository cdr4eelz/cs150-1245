# RegFile read/write/r0 tests; failures print 'Want:' lines (hardware/src/testbench/RegFileTestbench.v)
regfile.TOP     := RegFileTestbench
regfile.TB      := $(TBSRC)/RegFileTestbench.v
regfile.YDIRS   := $(SRC_YDIRS)
regfile.PASS_RE := ^All tests passed
regfile.FAIL_RE := Want:|FAIL
