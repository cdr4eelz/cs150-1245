TARGET ?= le
CSRCS ?= $(wildcard *.c)

all: $(TARGET)

$(TARGET): $(CSRCS)
	gcc -std=gnu99 $^ -o $@

%.c.llvm.s: %.c
	clang -cc1 -mrelocation-model static -S -o $@ $<

%.s.o: %.s
	as $< -o $<.o

clean:
	rm -f *.o *.llvm *.dump *.llvm.s *.log $(TARGET)

.PHONY: clean

