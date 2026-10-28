TARGET := proj7
ISR_TARGET := isr7
ISR_SHARED := shared7
LDSTYLE := as_scratchpair
FIXED_ELF ?= ../gios/gios.elf
SSRCS = $(START) #Don't include ISR assembly here, it builds separately

include ../makefile.pre
include ../makefile.in
include ../makefile.isr

$(TARGET).c.o $(ISR_SHARED).c.o: $(ISR_SHARED).h
