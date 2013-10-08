zeros.coe: nada.bin
	bin2coe < $^ > $@

nada.bin:
	truncate $@ -s 16K

clean:
	rm -f nada.bin zeros.coe

.phony: clean
