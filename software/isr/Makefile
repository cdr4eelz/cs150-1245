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
SHEXS := $(SELFS:%.elf=%.hex)

#PRE ?= mips-linux-gnu
PRE ?= mips-unknown-elf

default: mifs coes dumps hexes

all: objs elfs mifs coes vees dumps

%.dump: %.elf
	$(PRE)-objdump $(DUMPOPTS) $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	$(PRE)-objcopy --only-section=.text -O binary $< $@

%.hex: %.bin
	bin2coe < $^ |tail --lines=+3 |head --lines=-1 > $@

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $< > $@

%.elf: %.ld %.s.o
	$(PRE)-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T $^ -o $@ #HAD $< $^

%.s.o: %.s
	$(PRE)-as $(ASMOPTS) $< -o $<.o

elfs: $(SELFS)

objs: $(SOBJS)

mifs: $(SMIFS)

coes: $(SCOES)

vees: $(SVEES)

dumps: $(DUMPS)

hexes: $(SHEXS)

clean:
	rm -f *.elf *.bin *.mif *.coe *.v *.o *.ld *.dump *.list *.hex

.PHONY: clean all elfs objs mifs coes vees dumps hexes
.PRECIOUS: %.ld
