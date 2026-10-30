# GraphicsProcessor command fetch with fake memory/engines (hardware/src/testbench/GraphicsProcessorTestbench.v).
# FAIL_RE also catches the individual 'ERROR: (' lines (belt and braces: the bench's ELOG_errors counter
# used to be a 1-bit reg, so 'ERRORS: 0' could hide an even number of errors).
graphics_processor.TOP     := GraphicsProcessorTestbench
graphics_processor.TB      := $(TBSRC)/GraphicsProcessorTestbench.v
graphics_processor.YDIRS   := $(SRC_YDIRS)
graphics_processor.PASS_RE := ^ERRORS: 0
graphics_processor.FAIL_RE := ERROR: \(|ERRORS: [1-9]
