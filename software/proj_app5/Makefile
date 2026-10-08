TARGET := proj5
ISR_TARGET := isr5
LDSTYLE := as_scratchpair
FIXED_ELF ?= ../gios/gios.elf
SSRCS = $(START)
#COMCS ?= uart.c

include ../makefile.pre

include ../makefile.in

include ../makefile.isr

proj5.c.o shared.c.o: shared.h
