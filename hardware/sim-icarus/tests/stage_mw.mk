# StageMW smoke test (only instantiates/elaborates StageMW; hardware/src/testbench/StageMWTestbench.v)
stage_mw.TOP     := StageMWTestbench
stage_mw.TB      := $(TBSRC)/StageMWTestbench.v
stage_mw.YDIRS   := $(SRC_YDIRS)
stage_mw.PASS_RE := ^All tests passed
stage_mw.WFLAGS  := $(WFLAGS) -Wno-portbind   # the bench leaves StageMW inputs unconnected
