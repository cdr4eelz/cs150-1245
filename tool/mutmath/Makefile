TARGET ?= check_mutmath
CSRCS ?= $(wildcard *.c)
CC = gcc
CFLAGS ?= -std=gnu99 -Wall -Wextra -Wpedantic -O0 -g3 -fno-omit-frame-pointer \
	-fno-optimize-sibling-calls -fsanitize=address,undefined -fno-sanitize-recover=all

all: $(TARGET)

$(TARGET): $(CSRCS)
	$(CC) $(CFLAGS) $^ -o $@

%.c.llvm.s: %.c
	clang -cc1 -mrelocation-model static -S -o $@ $<

%.s.o: %.s
	as $< -o $<.o

clean:
	rm -f *.o *.llvm *.dump *.llvm.s *.log $(TARGET)

.PHONY: clean

