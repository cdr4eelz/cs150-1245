# Whole system as in ml505top: MIPS150 + Memory150 (caches, MIG) + Micron DDR2 model, running the
# BIOS (stack in DDR at 0x1F000000) and a sw/lw round trip through the dcache to DDR. Slow:
# MIG calibration alone is ~30 s wall; the CPU then runs at roughly 100-150 cycles/s.
sys_ddr_bios.TOP      := SysUART_tb
sys_ddr_bios.TB       := tb/SysUART_tb.v
sys_ddr_bios.SRCS     := $(SRC)/tuntap.vh $(SRC)/TunTap.v $(SRC)/cpu/MemMapIO.v $(SRC)/cpu/MemBank.v $(SRC)/base_io/UARTRVA.v $(DDR2_MODEL)
sys_ddr_bios.INCS     := $(TBSRC) $(SRC) $(DDR2_DIR)
sys_ddr_bios.YDIRS    := $(SYS_YDIRS)
sys_ddr_bios.DEFS     := SYS_DDR SYS_BIT_CLKS=8
sys_ddr_bios.NEEDS    := xilinx mips
sys_ddr_bios.GROUP    := slow
sys_ddr_bios.TIMEOUT  := 3600
sys_ddr_bios.SW_BIOS  := bios150v3
sys_ddr_bios.RUNFILES := tb/data/sys/ddr_bios.in tb/data/sys/ddr_bios.golden
sys_ddr_bios.PLUSARGS := +in=ddr_bios.in +golden=ddr_bios.golden +prompt=2> +max_cycles=400000
sys_ddr_bios.QUIET_RE := Untrapped ALU op:|^MEMIO: |^.\)  +@|Block Memory Generator|^blk_mem_gen_v7_3 collision detected
