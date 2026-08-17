DUMPOPTS ?= -xsD
# --disassembler-options=reg-names=numeric,no-aliases

ASMOPTS = --warn -g -ahlsgmd=$(patsubst %.s,%.list,$<)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)
SELFS := $(SSRCS:%.s=%.elf)
SMIFS := $(SELFS:%.elf=%.mif)
SCOES := $(SELFS:%.elf=%.coe)
SVEES := $(SELFS:%.elf=%.v)
DUMPS := $(SELFS:%.elf=%.dump)

PRE ?= mips64-linux-gnu

default: mifs coes dumps

all: objs elfs mifs coes vees dumps

%.dump: %.elf
	$(PRE)-objdump $(DUMPOPTS) $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	$(PRE)-objcopy --only-section=.text -O binary $< $@

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $< > $@

%.elf: %.ld %.s.o
###	$(PRE)-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T $^ -o $@ #HAD $< $^
	$(PRE)-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -Wl,--build-id=none -T $^ -o $@ #HAD $< $^

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

.PHONY: clean all elfs objs mifs coes vees dumps
.PRECIOUS: %.ld
