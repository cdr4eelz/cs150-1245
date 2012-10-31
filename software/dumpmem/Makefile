TARGET := dumpmem

default: all

all: $(TARGET)

$(TARGET):
	bin2mif < $(TARGET).bin > $(TARGET).mif
	bin2coe < $(TARGET).bin > $(TARGET).coe
	bin2rom $(TARGET) 0 < $(TARGET).bin > $(TARGET).v

clean:
	rm -f rm *.coe *.mif *.v

.phony: clean all

