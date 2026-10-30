# Regenerate the checked-in instruction images (*.hex, one big-endian 32-bit word per line)
# from the *.s sources here. Needs a MIPS GNU assembler (mips-linux-gnu-as by default).
#   make -C tb/data         (or `make hex` from sim-icarus/)
# cpu_isa_ddr.hex is cpu_isa.s assembled with --defsym DDR=1.
M_PRE ?= mips-linux-gnu
SRCS  := $(filter-out %.inc,$(wildcard *.s))
HEXES := $(SRCS:.s=.hex) cpu_isa_ddr.hex
ASFLAGS := -EB -mips32 -I.

all: $(HEXES)

define assemble
	$(M_PRE)-as $(ASFLAGS) $(2) $< -o $@.o
	$(M_PRE)-objcopy -O binary -j .text $@.o $@.bin
	perl -e 'binmode STDIN; local $$/; print map "$$_\n", unpack "(H8)*", <STDIN>' < $@.bin > $@
	rm -f $@.o $@.bin
endef

%.hex: %.s check.inc
	$(call assemble,$*,)

cpu_isa_ddr.hex: cpu_isa.s check.inc
	$(call assemble,cpu_isa_ddr,--defsym DDR=1)

clean-hex:
	rm -f $(HEXES)

.PHONY: all clean-hex
