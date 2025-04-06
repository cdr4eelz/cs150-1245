TO_MAKE = testdata.coe testdata.mif testdata.hex random.coe random.mif random.hex
RANDOM_KB=8

default: all
all: ${TO_MAKE}

random.bin:
	dd if=/dev/urandom of=random.bin bs=1K count=$(RANDOM_KB)

%.coe: %.bin
	bin2coe < $^ > $@

%.mif: %.bin
	bin2mif < $^ > $@

%.hex: %.bin
	create_mif.rb --format=hex $^ > $@

clean:
	rm -f *.coe *.mif *.hex

.phony: clean
