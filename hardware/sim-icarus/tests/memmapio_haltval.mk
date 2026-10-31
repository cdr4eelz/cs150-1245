# HaltVal store-then-load register at MMIO 0x80000084 through the real cpu/MemMapIO.v (tb/MemMapIO_haltval_tb.v)
memmapio_haltval.TOP      := MemMapIO_haltval_tb
memmapio_haltval.TB       := tb/MemMapIO_haltval_tb.v
memmapio_haltval.SRCS     := $(SRC)/cpu/MemMapIO.v $(SRC)/base_util/PRNG32LFSR.v $(SRC)/TunTap.v
memmapio_haltval.INCS     := $(SRC)
memmapio_haltval.DEFS     :=
memmapio_haltval.PLUSARGS :=
