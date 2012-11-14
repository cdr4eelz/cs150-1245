DUMPOPTS ?= -D --disassembler-options=reg-names=numeric,no-aliases

ASMOPTS = --warn -g -ahlsgm=$(patsubst %.s,%.list,$<)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)
SELFS := $(SSRCS:%.s=%.elf)
SMIFS := $(SELFS:%.elf=%.mif) $(SELFS:%.elf=%.data.mif)
SCOES := $(SELFS:%.elf=%.coe) $(SELFS:%.elf=%.data.coe)
SVEES := $(SELFS:%.elf=%.v)   $(SELFS:%.elf=%.data.v)
DUMPS := $(SELFS:%.elf=%.dump)

default: mifs coes

all: objs elfs mifs coes vees dumps multi

multi: objs
	mips-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T ld.multi $(SOBJS) -o multi.elf
	mips-objdump $(DUMPOPTS) multi.elf > multi.dump

%.dump: %.elf
	mips-objdump $(DUMPOPTS) $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	mips-objcopy --only-section=.text -O binary $< $@

%.data.bin: %.elf
	mips-objcopy --only-section=.data -O binary $< $@

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

.PHONY: clean multi all elfs objs mifs coes vees dumps

