# ByteAccess4 (innerds/ByteAccess4.v) exhaustive unit test vs. a behavioral MIPS big-endian model:
# every MemShift x SubIndex x IsSigned for ~250 data patterns; checks ByteMask, WordMasked
# (store data), ValExtract (load data: lb/lh sign-extend when IsSigned=1, lbu/lhu zero-extend),
# and all-zero outputs for unsupported/misaligned combos (tb/ByteAccess4_tb.v)
byte_access4.TOP      := ByteAccess4_tb
byte_access4.TB       := tb/ByteAccess4_tb.v
byte_access4.SRCS     := $(SRC)/innerds/ByteAccess4.v
byte_access4.PLUSARGS :=
