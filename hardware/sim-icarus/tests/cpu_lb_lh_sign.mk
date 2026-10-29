# Known bug: lb/lh sign extension (tb/CPU_prog_tb.v running tb/data/cpu_known_bugs_lb_lh.s on tb/CoreHarness.v)
cpu_lb_lh_sign.TOP      := CPU_prog_tb
cpu_lb_lh_sign.TB       := tb/CPU_prog_tb.v
cpu_lb_lh_sign.SRCS     := tb/CoreHarness.v
cpu_lb_lh_sign.YDIRS    := $(SRC_YDIRS)
cpu_lb_lh_sign.DEFS     := MAIN_HEX=\"cpu_known_bugs_lb_lh.hex\" NSTALL=4
cpu_lb_lh_sign.RUNFILES := tb/data/cpu_known_bugs_lb_lh.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
cpu_lb_lh_sign.QUIET_RE := Untrapped ALU op:|Not enough words in the file
cpu_lb_lh_sign.XFAIL    := lb/lh zero-extend instead of sign-extend (todo_master.txt); remove this line once fixed
