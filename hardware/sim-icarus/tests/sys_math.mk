# Whole MIPS150: BIOS jal's to software/math (mutmath mul16u32u/sqr16u32u, prints results with reference values); golden in tb/data/sys/math.golden
sys_math.TOP      := SysUART_tb
sys_math.TB       := tb/SysUART_tb.v
sys_math.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v
sys_math.INCS     := $(SRC)
sys_math.YDIRS    := $(SYS_YDIRS)
sys_math.NEEDS    := xilinx mips
sys_math.SW_BIOS  := bios150v3
sys_math.SW_PROG  := math
sys_math.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator
sys_math.RUNFILES := tb/data/sys/run_prog.in tb/data/sys/math.golden
sys_math.PLUSARGS := +in=run_prog.in +golden=math.golden +prompt=2> +ddr=ddr.hex +max_cycles=3000000 +gap=480
