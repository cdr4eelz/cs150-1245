TARGET := proj1
LDSTYLE := inject_cache
COMCS ?= uart.c
#SSRCS := start.s
#LIBOPTS ?= -nostartfiles -nodefaultlibs

include ../makefile.pre
# Old project code passes volatile buffers to non-volatile helpers; silence that warning here only
CCOPTS += -Wno-discarded-qualifiers

include ../makefile.in
