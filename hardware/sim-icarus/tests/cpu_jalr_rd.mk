# Known bug: jalr rd (tb/CPU_prog_tb.v running tb/data/cpu_known_bugs_jalr.s on tb/CoreHarness.v)
cpu_jalr_rd.TOP      := CPU_prog_tb
cpu_jalr_rd.TB       := tb/CPU_prog_tb.v
cpu_jalr_rd.SRCS     := tb/CoreHarness.v
cpu_jalr_rd.YDIRS    := $(SRC_YDIRS)
cpu_jalr_rd.DEFS     := MAIN_HEX=\"cpu_known_bugs_jalr.hex\" NSTALL=4
cpu_jalr_rd.RUNFILES := tb/data/cpu_known_bugs_jalr.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
cpu_jalr_rd.QUIET_RE := Untrapped ALU op:|Not enough words in the file
cpu_jalr_rd.XFAIL    := jalr always links to $$31 and ignores rd (todo_master.txt); remove this line once fixed
