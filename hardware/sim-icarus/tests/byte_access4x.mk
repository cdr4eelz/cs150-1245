# Legacy ByteAccess4 bench: byte/half write masks and lane placement, zero-extended loads
# (IsSigned tied to 0; hardware/src/testbench/ByteAccess4Testbench.v). The exhaustive test
# including lb/lh sign extension is byte_access4 (tb/ByteAccess4_tb.v).
byte_access4x.TOP     := ByteAccess4Testbench
byte_access4x.TB      := $(TBSRC)/ByteAccess4Testbench.v
byte_access4x.YDIRS   := $(SRC_YDIRS)
byte_access4x.PASS_RE := ^All tests passed
