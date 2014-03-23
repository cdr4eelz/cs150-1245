TARGET := example

CSRCS := $(wildcard *.c)
COBJS := $(CSRCS:%.c=%.c.o)

SSRCS := $(wildcard *.s)
SOBJS := $(SSRCS:%.s=%.s.o)

LDSRC := $(TARGET).ld

default: all
all: $(TARGET)


$(TARGET): $(COBJS) $(SOBJS)
	mips-gcc -mips1 -march=mips1 -mno-abicalls -fno-exceptions \
		 -msoft-float -mno-dsp -mno-mips3d -mno-branch-likely \
		 -mno-flush-func -fno-PIE -fno-PIC -fno-pie -fno-pic \
		 -nostartfiles -nostdlib -nodefaultlibs \
		 -T $(LDSRC) $^ -o $@.elf
	mips-strip -R .pdr -R .comment -R .reginfo $@.elf
	mips-objcopy -O binary $(TARGET).elf $(TARGET).bin
	bin2mif < $(TARGET).bin > $(TARGET).mif
	bin2coe < $(TARGET).bin > $(TARGET).coe
	bin2rom $(TARGET) 0 < $(TARGET).bin > $(TARGET).v

%.c.o: %.c
	mips-gcc -mips1 -march=mips1 -mno-abicalls -fno-exceptions \
		 -msoft-float -mno-dsp -mno-mips3d -mno-branch-likely \
		 -mno-flush-func -fno-PIE -fno-PIC -fno-pie -fno-pic \
		 -Wa,--no-break,--no-trap,-mno-pdr,-non_shared,-mno-shared,-O,-R \
		 -fasm -std=gnu99 -pedantic -ffreestanding -Os -g \
		 -c $< -o $@

%.s.o: %.s
	mips-as -mips1 -march=mips1 --no-break --no-trap \
		-mno-pdr -non_shared -mno-shared -R -g2 \
		$< -o $@

clean:
	rm -f $(COBJS) $(SOBJS) $(TARGET).elf $(TARGET).{bin,mif,v,coe}
