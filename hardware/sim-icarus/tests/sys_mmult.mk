# Whole MIPS150: BIOS jal's to software/mmult (4x4 matrix multiply, matrices in cache-side memory at 0x10018000); golden in tb/data/sys/mmult.golden
sys_mmult.TOP      := SysUART_tb
sys_mmult.TB       := tb/SysUART_tb.v
sys_mmult.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v
sys_mmult.INCS     := $(SRC)
sys_mmult.YDIRS    := $(SYS_YDIRS)
sys_mmult.NEEDS    := xilinx mips
sys_mmult.SW_BIOS  := bios150v3
sys_mmult.SW_PROG  := mmult
sys_mmult.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator
sys_mmult.RUNFILES := tb/data/sys/run_prog.in tb/data/sys/mmult.golden
sys_mmult.PLUSARGS := +in=run_prog.in +golden=mmult.golden +prompt=2> +ddr=ddr.hex +max_cycles=3000000
