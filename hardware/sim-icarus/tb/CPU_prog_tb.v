`timescale 1ns/1ps
// Runs a self-checking MIPS program (tb/data/*.s using check.inc) on CoreHarness
// (CPUMIPS + RegFile + COP0150, behavioral memories) and compares the
// (actual, expected) pairs the program wrote with CHECK.
//   defines: MAIN_HEX (default "cpu_isa.hex"), NSTALL (DDR store stall cycles, default 4),
//            MAX_CYCLES (default 20000), FORCE_FAIL
//   +vcd=<file>   dump waves
`ifndef MAIN_HEX
 `define MAIN_HEX "cpu_isa.hex"
`endif
`ifndef NSTALL
 `define NSTALL 4
`endif
`ifndef MAX_CYCLES
 `define MAX_CYCLES 20000
`endif
module CPU_prog_tb;
  localparam RESULTS_W = 32'h400 >> 2;            // x5 word index of RESULTS (0x50000400)
  reg clk=0, rst=1;
  always #10 clk = ~clk;
  CoreHarness #(.NSTALL(`NSTALL), .MAIN_HEX(`MAIN_HEX), .ISR_HEX("isr.hex")) h(.clk(clk), .rst(rst), .irq_tx(1'b0));

  integer cyc=0, i, n, errs=0, nstall=0;
  reg [31:0] act, exp;
  reg [8*256-1:0] fn;
  always @(posedge clk) if (!rst && h.stall) nstall = nstall + 1;
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, CPU_prog_tb); end
    repeat(5) @(posedge clk); rst = 0;
    while (h.x5[0] !== 32'h600DC0DE && cyc < `MAX_CYCLES) begin @(posedge clk); cyc = cyc + 1; end
    repeat(4) @(posedge clk);
    if (h.x5[0] !== 32'h600DC0DE) begin
      errs = errs + 1;
      $display("ERROR program %0s did not finish in %0d cycles (PC_DX=%h, %0d CHECK pairs written so far)",
               `MAIN_HEX, `MAX_CYCLES, h.core.PC_DX, n_written(0));
      n = n_written(0);
    end else n = h.x5[1];
    for (i=0; i<n; i=i+1) begin
      act = h.x5[RESULTS_W + 2*i]; exp = h.x5[RESULTS_W + 2*i + 1];
      if (act !== exp) begin errs = errs + 1; $display("ERROR check #%0d: got %h want %h", i, act, exp); end
    end
    if (n == 0) begin errs = errs + 1; $display("ERROR no CHECK results"); end
    $display("%0s: %0d checks, %0d failed, %0d cycles (%0d stalled, NSTALL=%0d)", `MAIN_HEX, n, errs, cyc, nstall, `NSTALL);
`ifdef FORCE_FAIL
    errs = errs + 1; $display("ERROR forced failure (FORCE_FAIL defined)");
`endif
    $display("CPU_prog_tb: ERRORS: %0d", errs);
    if (errs == 0) $display("PASS: CPU_prog_tb %0s", `MAIN_HEX); else $display("FAIL: CPU_prog_tb %0s (%0d errors)", `MAIN_HEX, errs);
    $finish;
  end
  // pairs written so far = first all-zero expected slot (for a program that never finished)
  function integer n_written(input integer dummy);
    integer k; begin n_written = 0; for (k=0; k<512; k=k+1) if (n_written==k && h.x5[RESULTS_W+2*k+1] !== 0) n_written = k+1; end
  endfunction
endmodule
