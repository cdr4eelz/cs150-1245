# GraphicsProcessor command fetch with fake memory/engines (hardware/src/testbench/GraphicsProcessorTestbench.v).
# NOTE: that bench's error counter is a 1-bit reg (ELOG_errors), so 'ERRORS: 0' can hide an even number of
# errors; FAIL_RE therefore also catches the individual 'ERROR: (' lines.
graphics_processor.TOP     := GraphicsProcessorTestbench
graphics_processor.TB      := $(TBSRC)/GraphicsProcessorTestbench.v
graphics_processor.YDIRS   := $(SRC_YDIRS)
graphics_processor.PASS_RE := ^ERRORS: 0
graphics_processor.FAIL_RE := ERROR: \(|ERRORS: [1-9]
