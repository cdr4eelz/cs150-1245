TARGET := proj3
LDSTYLE := as_scratchpair
COMCS ?= uart.c

include ../makefile.pre
# Old project code passes volatile buffers to non-volatile helpers; silence that warning here only
CCOPTS += -Wno-discarded-qualifiers

include ../makefile.in
