# Counter up/down wrap/boundary tests (hardware/src/testbench/CounterBoundaryTestbench.v)
counter_boundary.TOP     := CounterBoundaryTestbench
counter_boundary.TB      := $(TBSRC)/CounterBoundaryTestbench.v
counter_boundary.YDIRS   := $(SRC_YDIRS)
counter_boundary.PASS_RE := ^All Counter boundary tests passed
