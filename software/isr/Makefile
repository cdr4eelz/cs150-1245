DUMPOPTS ?= -xsD
# --disassembler-options=reg-names=numeric,no-aliases

ASMOPTS = --warn -g -ahlsgm=$(patsubst %.s,%.list,$<)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)
SELFS := $(SSRCS:%.s=%.elf)
SMIFS := $(SELFS:%.elf=%.mif)
SCOES := $(SELFS:%.elf=%.coe)
SVEES := $(SELFS:%.elf=%.v)
DUMPS := $(SELFS:%.elf=%.dump)

default: mifs coes dumps

all: objs elfs mifs coes vees dumps

%.dump: %.elf
	mips-objdump $(DUMPOPTS) $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	mips-objcopy --only-section=.text -O binary $< $@

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $< > $@

%.elf: %.ld %.s.o
	mips-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T $< $^ -o $@

%.s.o: %.s
	mips-as $(ASMOPTS) $< -o $<.o

elfs: $(SELFS)

objs: $(SOBJS)

mifs: $(SMIFS)

coes: $(SCOES)

vees: $(SVEES)

dumps: $(DUMPS)

clean:
	rm -f *.elf *.bin *.mif *.coe *.v *.o *.ld *.dump *.list

.PHONY: clean all elfs objs mifs coes vees dumps
.PRECIOUS: %.ld
