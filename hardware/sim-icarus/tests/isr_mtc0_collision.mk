# Interrupt EPC regression (tb/ISR_EPC_tb.v): NSTALL=0, IRQ every 37 cycles, main program tb/data/main_mtc0.s; also fails if mtc0 collides with interrupt dispatch
isr_mtc0_collision.TOP      := ISR_EPC_tb
isr_mtc0_collision.TB       := tb/ISR_EPC_tb.v
isr_mtc0_collision.SRCS     := tb/CoreHarness.v
isr_mtc0_collision.YDIRS    := $(SRC_YDIRS)
isr_mtc0_collision.DEFS     := NSTALL=0 IRQ_PERIOD=37 MAIN_HEX=\"main_mtc0.hex\" CHECK_COLLISION
isr_mtc0_collision.RUNFILES := tb/data/main_mtc0.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
isr_mtc0_collision.QUIET_RE := Untrapped ALU op:|Not enough words in the file
