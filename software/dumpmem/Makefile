BINFILES ?= $(wildcard *.bin)
TARGETS ?= $(BINFILES:%.bin=%)
MIFS ?= $(TARGETS:%=%.mif)
COES ?= $(TARGETS:%=%.coe)
VEES ?= $(TARGETS:%=%.v)


default: all

all: count mifs coes vees

count: $(BINFILES)
	ls -al $(BINFILES)
	wc -c $(BINFILES)

mifs: $(MIFS)

coes: $(COES)

vees: $(VEES)

%.mif: %.bin
	bin2mif < $< > $@

%.coe: %.bin
	bin2coe < $< > $@

%.v: %.bin
	bin2rom $(TARGET) 0 < $(TARGET).bin > $(TARGET).v

clean:
	rm -f rm *.coe *.mif *.v

.phony: clean all count

