# Debouncer latched/continuous modes (hardware/src/testbench/DebouncerTestbench.v)
debouncer.TOP     := DebouncerTestbench
debouncer.TB      := $(TBSRC)/DebouncerTestbench.v
debouncer.YDIRS   := $(SRC_YDIRS)
debouncer.PASS_RE := ^All Debouncer mode tests passed
