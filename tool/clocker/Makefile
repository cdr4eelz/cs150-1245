TARGET ?= clocker
CSRCS ?= $(TARGET).c
#$(wildcard *.c)

all: $(TARGET) clock_hand.c

$(TARGET): $(CSRCS)
	gcc -std=gnu99 -Wall $^ -o $@ -lm

clock_hand.c: $(TARGET)
	./$(TARGET) |tee clock_hand.c

clean:
	rm -f *.o *.dump *.log $(TARGET) clock_hand.*

.PHONY: clean

