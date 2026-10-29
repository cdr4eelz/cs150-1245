# Whole MIPS150 (BRAMs, MemMapIO, UART) running the real BIOS (software/bios150v3) over its
# serial port: sw/sh/sb/lw/lhu/lbu on DMEM and cache-side memory, code written to IMEM and
# run with jal, PRNG reads at 0x80000080. Golden transcript: tb/data/sys/bios.golden
sys_bios.TOP      := SysUART_tb
sys_bios.TB       := tb/SysUART_tb.v
sys_bios.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v
sys_bios.INCS     := $(SRC)
sys_bios.YDIRS    := $(SYS_YDIRS)
sys_bios.NEEDS    := xilinx mips
sys_bios.SW_BIOS  := bios150v3
sys_bios.RUNFILES := tb/data/sys/bios.in tb/data/sys/bios.golden
sys_bios.PLUSARGS := +in=bios.in +golden=bios.golden +prompt=2> +max_cycles=1000000
sys_bios.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator
