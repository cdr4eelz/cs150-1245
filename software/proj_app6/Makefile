TARGET := proj6
ISR_TARGET := isr6
ISR_SHARED := shared6
LDSTYLE := as_scratchpair
FIXED_ELF ?= ../gios/gios.elf
SSRCS = $(START)

include ../makefile.pre
include ../makefile.in
include ../makefile.isr

$(TARGET).c.o $(ISR_SHARED).c.o: $(ISR_SHARED).h
