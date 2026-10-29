# PRNG at MMIO 0x80000080 through the real cpu/MemMapIO.v
memmapio_prng.TOP      := MemMapIO_prng_tb
memmapio_prng.TB       := tb/MemMapIO_prng_tb.v
memmapio_prng.SRCS     := $(SRC)/cpu/MemMapIO.v $(SRC)/base_util/PRNG32LFSR.v $(SRC)/TunTap.v
memmapio_prng.INCS     := $(SRC)
memmapio_prng.DEFS     :=
memmapio_prng.PLUSARGS :=
