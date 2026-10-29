# Same ISA test with the load/store area in "DDR" so every store stalls the CPU for 4 cycles (tb/CPU_prog_tb.v running tb/data/cpu_isa_ddr.s on tb/CoreHarness.v)
cpu_isa_ddr.TOP      := CPU_prog_tb
cpu_isa_ddr.TB       := tb/CPU_prog_tb.v
cpu_isa_ddr.SRCS     := tb/CoreHarness.v
cpu_isa_ddr.YDIRS    := $(SRC_YDIRS)
cpu_isa_ddr.DEFS     := MAIN_HEX=\"cpu_isa_ddr.hex\" NSTALL=4
cpu_isa_ddr.RUNFILES := tb/data/cpu_isa_ddr.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
cpu_isa_ddr.QUIET_RE := Untrapped ALU op:|Not enough words in the file
