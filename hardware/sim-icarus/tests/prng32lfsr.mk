# PRNG32LFSR unit test (100k cycles by default; e.g. DEFINES=PRNG_CYCLES=1000000 or PLUSARGS=+n=1000000)
prng32lfsr.TOP      := PRNG32LFSR_tb
prng32lfsr.TB       := tb/PRNG32LFSR_tb.v
prng32lfsr.SRCS     := $(SRC)/base_util/PRNG32LFSR.v
prng32lfsr.INCS     :=
prng32lfsr.DEFS     :=
prng32lfsr.PLUSARGS :=
