TARGET := example

CSRCS := $(wildcard *.c)
COBJS := $(CSRCS:%.c=%.c.o)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)

LDSRC := $(TARGET).ld

TARGET_KEY ?= $(TARGET).elf $(TARGET).bin $(TARGET).mif $(TARGET).coe
TARGET_ALL ?= $(TARGET_KEY) $(TARGET).v $(TARGET).hak $(TARGET).mem \
	      	$(TARGET)_rom.mif $(TARGET).dis $(COBJS) $(SOBJS)

default: $(TARGET_KEY)
all: $(TARGET_ALL)

#PRE ?= mips-linux-gnu
PRE ?= mips-unknown-elf

$(TARGET).elf: $(COBJS) $(SOBJS)
	$(PRE)-gcc -mips1 -march=mips1 -mno-abicalls -fno-exceptions \
		 -msoft-float -mno-dsp -mno-mips3d -mno-branch-likely \
		 -mno-flush-func -fno-PIE -fno-PIC -fno-pie -fno-pic \
		 -nostartfiles -nostdlib -nodefaultlibs \
		 -T $(LDSRC) $^ -o $@
	$(PRE)-strip -R .pdr -R .comment -R .reginfo $@

$(TARGET).bin: $(TARGET).elf
	$(PRE)-objcopy -O binary -j .text -p $(TARGET).elf $@

$(TARGET).coe: $(TARGET).bin
	bin2coe < $(TARGET).bin > $@
$(TARGET).mif: $(TARGET).bin
	bin2mif < $(TARGET).bin > $@
$(TARGET).hak: $(TARGET).bin
	bin2hak < $(TARGET).bin > $@
$(TARGET).mem: $(TARGET).bin
	bin2mem < $(TARGET).bin > $@
$(TARGET).v: $(TARGET).bin
	bin2rom $(TARGET) 0 < $(TARGET).bin > $@
$(TARGET)_rom.mif: $(TARGET).mif
	mif2rom $(TARGET).mif #Creates XYZ_rom.mif output
$(TARGET).dis: $(TARGET).mif
	mif2s   $(TARGET).mif > $@  ##Like disassembly

%.c.o: %.c
	$(PRE)-gcc -mips1 -march=mips1 -mno-abicalls -fno-exceptions \
		 -msoft-float -mno-dsp -mno-mips3d -mno-branch-likely \
		 -mno-flush-func -fno-PIE -fno-PIC -fno-pie -fno-pic \
		 -Wa,--no-break,--no-trap,-mno-pdr,-non_shared,-mno-shared,-O,-R \
		 -fasm -std=gnu99 -pedantic -ffreestanding -Os -g \
		 -c $< -o $@

%.s.o: %.s
	$(PRE)-as -mips1 -march=mips1 --no-break --no-trap \
		-mno-pdr -non_shared -mno-shared -msoft-float -R -g2 \
		$< -o $@

clean:
	rm -f $(TARGET_ALL)
#	rm -f $(COBJS) $(SOBJS) $(TARGET).elf $(TARGET).bin $(TARGET).mif \
		$(TARGET).v $(TARGET).coe $(TARGET).hak $(TARGET).mem \
		$(TARGET)_rom.mif $(TARGET).dis

.PHONY: clean all
