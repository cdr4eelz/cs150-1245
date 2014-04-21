default: all
all: zeros.coe zeros.mif

zeros.coe: nada.bin
	bin2coe < $^ > $@

zeros.mif: nada.bin
	bin2mif < $^ > $@

nada.bin:
	truncate $@ -s 16K

clean:
	rm -f nada.bin zeros.coe

.phony: clean
