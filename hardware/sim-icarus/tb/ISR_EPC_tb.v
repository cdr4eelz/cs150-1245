`timescale 1ns/1ps
// Interrupt/EPC regression (ported from the proj6/isr6 freeze investigation, fixed in 5cba58a).
// A periodic UATX interrupt hits a main loop that (a) stores to "DDR" so the CPU stalls
// right around interrupt dispatch (main_ddr.s), or (b) does mfc0/mtc0 Status
// read-modify-write so mtc0 collides with interrupt dispatch (main_mtc0.s).
// isr.s records the EPC it sees and returns. Fails if any EPC captured on
// interrupt is not in main code (0x6xxxxxxx), if an mtc0 collides with dispatch
// (CHECK_COLLISION), or if the ISR or main loop stop making progress.
//   defines: NSTALL (stall cycles per DDR store), IRQ_PERIOD (cycles), CYCLES,
//            MAIN_HEX, CHECK_COLLISION, FORCE_FAIL
`ifndef NSTALL
 `define NSTALL 4
`endif
`ifndef IRQ_PERIOD
 `define IRQ_PERIOD 37
`endif
`ifndef CYCLES
 `define CYCLES 20000
`endif
`ifndef MAIN_HEX
 `define MAIN_HEX "main_ddr.hex"
`endif
module ISR_EPC_tb;
  reg clk=0, rst=1, irq_tx=0;
  always #10 clk = ~clk;
  CoreHarness #(.NSTALL(`NSTALL), .MAIN_HEX(`MAIN_HEX), .ISR_HEX("isr.hex")) h(.clk(clk), .rst(rst), .irq_tx(irq_tx));

  integer cyc = 0;
  always @(posedge clk) begin
    cyc <= cyc + 1;
    irq_tx <= (!rst && cyc > 50 && (cyc % `IRQ_PERIOD) == 0);
  end
  integer nisr = 0, nbad = 0, ncoll = 0, errs = 0;
  always @(posedge clk) if (!rst && h.intr_handled) begin
    nisr = nisr + 1;
    if (h.intr_pc[31:28] != 4'h6) begin
      nbad = nbad + 1;
      if (nbad <= 3) $display("cycle %0d: BAD EPC captured = %h (stall_cnt=%0d)", cyc, h.intr_pc, h.stall_cnt);
    end
  end
`ifdef CHECK_COLLISION
  always @(posedge clk) if (!rst && h.intr_handled && h.COP0_we) begin
    ncoll = ncoll + 1;
    if (ncoll <= 3) $display("cycle %0d: COLLISION intr_handled with mtc0 in DX; epc=%h (should be %h)", cyc, h.cop0.epc, h.intr_pc);
  end
`endif
  reg [8*256-1:0] fn;
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, ISR_EPC_tb); end
    repeat(5) @(posedge clk); rst = 0;
    repeat(`CYCLES) @(posedge clk);
    $display("NSTALL=%0d IRQ_PERIOD=%0d main=%0s: ISR entries=%0d, bad EPCs=%0d, collisions=%0d, main progress=%0d, last EPC breadcrumb=%h",
      `NSTALL, `IRQ_PERIOD, `MAIN_HEX, nisr, nbad, ncoll, h.x5[64], h.x5[4]);
    errs = nbad + ncoll;
    if (nisr < (`CYCLES / `IRQ_PERIOD) / 2) begin errs = errs + 1; $display("ERROR too few ISR entries (%0d)", nisr); end
    if (h.x5[64] < 100) begin errs = errs + 1; $display("ERROR main loop made too little progress (%0d)", h.x5[64]); end
    if (h.x5[4][31:28] != 4'h6) begin errs = errs + 1; $display("ERROR ISR breadcrumb EPC %h not in main code", h.x5[4]); end
`ifdef FORCE_FAIL
    errs = errs + 1; $display("ERROR forced failure (FORCE_FAIL defined)");
`endif
    $display("ISR_EPC_tb: ERRORS: %0d", errs);
    if (errs == 0) $display("PASS: ISR_EPC_tb"); else $display("FAIL: ISR_EPC_tb (%0d errors)", errs);
    $finish;
  end
endmodule
