TARGET := proj5
ISR_TARGET := isr5
ISR_SHARED := shared
LDSTYLE := as_scratchpair
FIXED_ELF ?= ../gios/gios.elf
SSRCS = $(START)
#COMCS ?= uart.c

include ../makefile.pre
include ../makefile.in
include ../makefile.isr

$(TARGET).c.o $(ISR_SHARED).c.o: $(ISR_SHARED).h
