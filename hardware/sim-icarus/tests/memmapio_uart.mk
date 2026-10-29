# MMIO UART registers + serial loopback through UARTRVA/UART, and the cycle/instruction counters (tb/MemMapIO_uart_tb.v)
memmapio_uart.TOP   := MemMapIO_uart_tb
memmapio_uart.TB    := tb/MemMapIO_uart_tb.v
memmapio_uart.INCS  := $(SRC)
memmapio_uart.YDIRS := $(SRC_YDIRS)
memmapio_uart.SRCS  := $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/base_io/UARTRVA.v $(SRC)/base_io/UART.v
# (listed explicitly: TunTap.v holds BUS_RVA_tap/tun, and MemMapIO/UARTRVA do not parse as -y library files)
