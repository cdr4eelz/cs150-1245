# StageDX (decode/execute) tests; a failure prints 'Expected ...' and stops early (hardware/src/testbench/StageDXTestbench.v)
stage_dx.TOP     := StageDXTestbench
stage_dx.TB      := $(TBSRC)/StageDXTestbench.v
stage_dx.YDIRS   := $(SRC_YDIRS)
stage_dx.PASS_RE := ^All tests passed
stage_dx.FAIL_RE := Expected|FAIL
