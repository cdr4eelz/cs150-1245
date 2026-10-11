TARGET ?= clocker
CSRCS ?= $(TARGET).c
#$(wildcard *.c)
CC = gcc
CFLAGS ?= -std=gnu99 -Wall -Wextra -Wpedantic -O0 -g3 -fno-omit-frame-pointer \
	-fno-optimize-sibling-calls -fsanitize=address,undefined -fno-sanitize-recover=all

all: $(TARGET) clock_hand.c

$(TARGET): $(CSRCS)
	$(CC) $(CFLAGS) $^ -o $@ -lm

clock_hand.c: $(TARGET)
	./$(TARGET) |tee clock_hand.c

clean:
	rm -f *.o *.dump *.log $(TARGET) clock_hand.*

.PHONY: clean

