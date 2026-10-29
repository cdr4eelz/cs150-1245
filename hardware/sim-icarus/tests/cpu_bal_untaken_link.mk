# Known deviation: untaken bltzal/bgezal do not link (tb/CPU_prog_tb.v running tb/data/cpu_known_bugs_bal.s on tb/CoreHarness.v)
cpu_bal_untaken_link.TOP      := CPU_prog_tb
cpu_bal_untaken_link.TB       := tb/CPU_prog_tb.v
cpu_bal_untaken_link.SRCS     := tb/CoreHarness.v
cpu_bal_untaken_link.YDIRS    := $(SRC_YDIRS)
cpu_bal_untaken_link.DEFS     := MAIN_HEX=\"cpu_known_bugs_bal.hex\" NSTALL=4
cpu_bal_untaken_link.RUNFILES := tb/data/cpu_known_bugs_bal.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
cpu_bal_untaken_link.QUIET_RE := Untrapped ALU op:|Not enough words in the file
cpu_bal_untaken_link.XFAIL    := StageDX.v suppresses the link write for an untaken bltzal/bgezal (MIPS32 always links); remove this line if changed
