TO_MAKE= testdata.coe testdata.mif testdata.hex

default: all
all: ${TO_MAKE}

%.coe: %.bin
	bin2coe < $^ > $@

%.mif: %.bin
	bin2mif < $^ > $@

%.hex: %.bin
	create_mif.rb --format=hex $^ > $@

clean:
	rm -f testdata.coe testdata.mif testdata.hex

.phony: clean
