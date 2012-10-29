
SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)
SELFS := $(SSRCS:%.s=%.elf)
SBINS := $(SELFS:%.elf=%.bin)
SMIFS := $(SBINS:%.bin=%.mif)
SCOES := $(SBINS:%.bin=%.coe)
SVEES := $(SBINS:%.bin=%.v)
DUMPS := $(SELFS:%.elf=%.dump)

default: mifs coes dumps

all: objs bins mifs coes vees dumps

multi: objs
	mips-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T ld.multi $(SOBJS) -o multi.elf
	mips-objdump -D multi.elf > multi.dump

%.dump: %.elf
	mips-objdump -D $< > $@

%.ld: %.s
	sed "s/##ASMNAME##/$$(basename $<)/" < ld.each > $@

%.bin: %.elf
	mips-objcopy -O binary $< $@

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $< > $@

%.elf: %.ld %.s.o
	mips-gcc -static -nostartfiles -nostdlib -nodefaultlibs -G0 -T $< $^ -o $@

%.s.o: %.s
	mips-as $< -o $<.o

objs: $(SOBJS)

bins: $(SBINS)

mifs: $(SMIFS)

coes: $(SCOES)

vees: $(SVEES)

dumps: $(DUMPS)

clean:
	rm -f *.elf *.bin *.mif *.coe *.v *.o *.ld *.dump

