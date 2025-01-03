TARGET := example

CSRCS := $(wildcard *.c)
COBJS := $(CSRCS:%.c=%.c.o)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)

LDSRC := $(TARGET).ld

default: all
all: $(TARGET)

PRE ?= mips-linux-gnu

$(TARGET): $(COBJS) $(SOBJS)
	$(PRE)-gcc -mips1 -march=mips1 -mno-abicalls -fno-exceptions \
		 -msoft-float -mno-dsp -mno-mips3d -mno-branch-likely \
		 -mno-flush-func -fno-PIE -fno-PIC -fno-pie -fno-pic \
		 -nostartfiles -nostdlib -nodefaultlibs \
		 -T $(LDSRC) $^ -o $@.elf
	$(PRE)-strip -R .pdr -R .comment -R .reginfo $@.elf
	$(PRE)-objcopy -O binary -j .text -p $(TARGET).elf $(TARGET).bin
	bin2coe < $(TARGET).bin > $(TARGET).coe
	bin2hak < $(TARGET).bin > $(TARGET).hak
	bin2mem < $(TARGET).bin > $(TARGET).mem
	bin2mif < $(TARGET).bin > $(TARGET).mif
	bin2rom $(TARGET) 0 < $(TARGET).bin > $(TARGET).v
	mif2rom $(TARGET).mif #Creates XYZ_rom.mif output
	mif2s   $(TARGET).mif > $(TARGET).dis #Like disassembly

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
	rm -f $(COBJS) $(SOBJS) $(TARGET).elf $(TARGET).bin $(TARGET).mif \
		$(TARGET).v $(TARGET).coe $(TARGET).hak $(TARGET).mem \
		$(TARGET).rom $(TARGET)_rom.mif $(TARGET).dis

