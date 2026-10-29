# CPU ISA smoke test: ALU, shifts, forwarding, loads/stores, branches, jumps/links, COP0 regs (tb/CPU_prog_tb.v running tb/data/cpu_isa.s on tb/CoreHarness.v)
cpu_isa.TOP      := CPU_prog_tb
cpu_isa.TB       := tb/CPU_prog_tb.v
cpu_isa.SRCS     := tb/CoreHarness.v
cpu_isa.YDIRS    := $(SRC_YDIRS)
cpu_isa.DEFS     := MAIN_HEX=\"cpu_isa.hex\" NSTALL=4
cpu_isa.RUNFILES := tb/data/cpu_isa.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
cpu_isa.QUIET_RE := Untrapped ALU op:|Not enough words in the file
