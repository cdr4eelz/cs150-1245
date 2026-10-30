# Whole MIPS150: BIOS jal's to software/echo_c (built with LDSTYLE=inject_cache, loaded at 0x10000000 in the cache-side memory), which echoes text sent over the UART
sys_echo.TOP      := SysUART_tb
sys_echo.TB       := tb/SysUART_tb.v
sys_echo.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v
sys_echo.INCS     := $(SRC)
sys_echo.YDIRS    := $(SYS_YDIRS)
sys_echo.NEEDS    := xilinx mips coregen
sys_echo.SW_BIOS  := bios150v3
sys_echo.SW_PROG  := echo_c
sys_echo.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator
sys_echo.SW_ARGS  := LDSTYLE=inject_cache
sys_echo.RUNFILES := tb/data/sys/echo.in tb/data/sys/echo.golden
sys_echo.PLUSARGS := +in=echo.in +golden=echo.golden +prompt=2> +prompt_lines=1 +ddr=ddr.hex +max_cycles=1000000
