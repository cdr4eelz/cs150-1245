DUMPOPTS ?= -D --disassembler-options=reg-names=numeric,no-aliases

ASMOPTS = --warn -g -ahlsgm=$(patsubst %.s,%.list,$<)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)
SELFS := $(SSRCS:%.s=%.elf)
SMIFS := $(SELFS:%.elf=%.mif) $(SELFS:%.elf=%.data.mif)
SCOES := $(SELFS:%.elf=%.coe) $(SELFS:%.elf=%.data.coe)
SVEES := $(SELFS:%.elf=%.v)   $(SELFS:%.elf=%.data.v)
DUMPS := $(SELFS:%.elf=%.dump)

PRE ?= mips64-linux-gnu

default: mifs coes

all: objs elfs mifs coes vees dumps multi

multi: objs
	$(PRE)-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T ld.multi $(SOBJS) -o multi.elf
	$(PRE)-objdump $(DUMPOPTS) multi.elf > multi.dump

%.dump: %.elf
	$(PRE)-objdump $(DUMPOPTS) $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	$(PRE)-objcopy --only-section=.text -O binary $< $@

%.data.bin: %.elf
	$(PRE)-objcopy --only-section=.data -O binary $< $@

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $< > $@

%.elf: %.ld %.s.o
	$(PRE)-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T  $^ -o $@  ## Had $< $^ -o $@

%.s.o: %.s
	$(PRE)-as $(ASMOPTS) $< -o $<.o

elfs: $(SELFS)

objs: $(SOBJS)

mifs: $(SMIFS)

coes: $(SCOES)

vees: $(SVEES)

dumps: $(DUMPS)

clean:
	rm -f *.elf *.bin *.mif *.coe *.v *.o *.ld *.dump *.list

.PHONY: clean multi all elfs objs mifs coes vees dumps

