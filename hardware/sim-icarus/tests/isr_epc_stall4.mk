# Interrupt EPC regression (tb/ISR_EPC_tb.v): NSTALL=4, IRQ every 37 cycles, main program tb/data/main_ddr.s
isr_epc_stall4.TOP      := ISR_EPC_tb
isr_epc_stall4.TB       := tb/ISR_EPC_tb.v
isr_epc_stall4.SRCS     := tb/CoreHarness.v
isr_epc_stall4.YDIRS    := $(SRC_YDIRS)
isr_epc_stall4.DEFS     := NSTALL=4 IRQ_PERIOD=37 MAIN_HEX=\"main_ddr.hex\"
isr_epc_stall4.RUNFILES := tb/data/main_ddr.hex tb/data/isr.hex
# ALUdec.v prints "Untrapped ALU op" for COP0 instructions and for delta-cycle glitches of its
# combinational decode (not real instructions); the short .hex files trigger $readmemh size warnings
isr_epc_stall4.QUIET_RE := Untrapped ALU op:|Not enough words in the file
