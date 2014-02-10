TARGET ?= example
A_INC ?= 
#C_INC ?= /opt/diet/include
#L_INC ?= /opt/diet/lib-mips
#L_INK ?= c gcc
C_INC ?= #/opt/uclibc/usr/mips-linux-uclibc/usr/include
L_INC ?= #/opt/uclibc/usr/mips-linux-uclibc/usr/lib
L_INK ?= #c gcc
L_OBJ ?= 

M_PRE ?= mips-
M_GCC ?= -nostartfiles -march=mips1 -mabi=32
M_AS ?= $(A_INC:%=-I%)
M_CC ?= -std=gnu99 $(C_INC:%=-I%)
M_LD ?= -static $(L_INC:%=-L%) $(L_INK:%=-l%) $(L_OBJ)

CSRCS ?= $(wildcard *.c)
SSRCS ?= $(wildcard *.s)

COBJS ?= $(CSRCS:%.c=%.c.s.o)
SOBJS ?= $(SSRCS:%.s=%.s.o)

LDSRC ?= $(TARGET).ld

default: $(TARGET).coe $(TARGET).mif $(TARGET).dump
.SECONDARY:

$(TARGET).elf: $(CSRCS) $(SSRCS)
	$(M_PRE)gcc $(M_GCC) $(M_AS) $(M_CC) $^ $(M_LD) -T $(LDSRC) -o $@

#$(TARGET).elf: $(COBJS) $(SOBJS)
#	$(M_PRE)gcc $(M_GCC) $^ $(M_LD) -T $(LDSRC) -o $@
#	$(M_PRE)strip -R .pdr -R .comment -R .reginfo $@

%.c.s: %.c
	$(M_PRE)gcc $(M_GCC) -S $(M_CC) $< -o $@
%.c.o: %.c
	$(M_PRE)gcc $(M_GCC) -c $(M_CC) $< -o $@
%.s.o: %.s
	$(M_PRE)gcc $(M_GCC) -c $(M_AS) $< -o $@

%.dump: %.elf
	$(M_PRE)objdump $^ -xsD >$@
%.bin: %.elf
	$(M_PRE)objcopy -j .text -p -O binary $< $@
	chmod -x $@
%.mif: %.bin
	bin2mif < $< > $@
%.coe: %.bin
	bin2coe < $< > $@
%.v: %.bin
	bin2rom $% 0 < $< > $@

clean:
	rm -f *.o *.c.s *.elf *.bin *.mif *.coe *.v *.dump
.phony: $(TARGET) clean

