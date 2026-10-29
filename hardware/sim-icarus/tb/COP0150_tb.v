`timescale 1ns/1ps
// Unit test for cpu/COP0150.v: reset values, Count/Compare/Status read-write,
// Cause latching of interrupt lines (sticky, even when masked), intr_request =
// IE & |(IM & IP), EPC capture + IE clear on intr_handled, EPC not writable,
// Cause write-to-clear semantics, timer (Count==Compare) and its clear-on-Compare-write.
//   +vcd=<file>   dump waves;   -DFORCE_FAIL  inject one error
module COP0150_tb;
  reg clk=0, rst=1, we=0, handled=0; reg [31:0] wd=0, ipc=0; reg [4:0] ra=0;
  reg rx=0, tx=0, pf=0, gp=0;
  wire [31:0] rd; wire req;
  COP0150 dut(.clk(clk), .ena(1'b1), .rst(rst), .COP0_we(we), .COP0_wd(wd), .COP0_ra(ra), .COP0_rd(rd),
    .intr_pc(ipc), .intr_handled(handled), .intr_request(req),
    .irq_UARX(rx), .irq_UATX(tx), .irq_pf_frame(pf), .irq_gp_done(gp));
  always #5 clk = ~clk;
  localparam COUNT=9, COMPARE=11, STATUS=12, CAUSE=13, EPC=14;
  integer errs = 0; reg [31:0] v, c0;
  task rdr(input [4:0] a, output [31:0] val); begin ra = a; #1 val = rd; end endtask
  task wrr(input [4:0] a, input [31:0] d); begin @(negedge clk); ra=a; wd=d; we=1; @(negedge clk); we=0; end endtask
  task expect(input [4:0] a, input [31:0] mask, input [31:0] want, input [8*40-1:0] what);
    begin rdr(a, v); if ((v & mask) !== want) begin errs=errs+1; $display("ERROR %0s: reg %0d = %h (mask %h) want %h", what, a, v, mask, want); end end
  endtask
  // one-cycle pulse on an interrupt line: 0=UARX 1=UATX 2=pf_frame 3=gp_done
  task pulse(input integer which);
    begin @(negedge clk); {gp,pf,tx,rx} = 4'b1 << which; @(negedge clk); {gp,pf,tx,rx} = 4'b0; end
  endtask
  task chkreq(input want, input [8*40-1:0] what);
    begin #1 if (req !== want) begin errs=errs+1; $display("ERROR %0s: intr_request=%b want %b", what, req, want); end end
  endtask
  reg [8*256-1:0] fn;
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, COP0150_tb); end
    repeat(3) @(negedge clk); rst = 0;
    expect(STATUS, 32'hFFFFFFFF, 0, "reset Status");
    expect(CAUSE, 32'hFFFFFFFF, 0, "reset Cause");
    expect(COMPARE, 32'hFFFFFFFF, 32'hFFFF, "reset Compare");
    expect(EPC, 32'hFFFFFFFF, 0, "reset EPC");
    rdr(COUNT, c0); repeat(5) @(negedge clk); rdr(COUNT, v);
    if (v - c0 != 5) begin errs=errs+1; $display("ERROR Count advanced %0d in 5 cycles", v - c0); end
    chkreq(0, "idle");
    // UATX enabled (IM bit 11), IE off: pending but no request
    wrr(STATUS, 32'h0000_0800);
    pulse(1);
    expect(CAUSE, 32'h0000_FC00, 32'h0000_0800, "UATX latched in Cause");
    chkreq(0, "IE=0");
    // UARX pulse while masked: latched (sticky) but no request from it
    pulse(0);
    expect(CAUSE, 32'h0000_FC00, 32'h0000_0C00, "UARX latched even when masked");
    wrr(STATUS, 32'h0000_0801);          // IE=1
    chkreq(1, "IE=1 & UATX pending");
    // CPU takes the interrupt
    @(negedge clk); ipc = 32'h6000_0040; handled = 1; @(negedge clk); handled = 0;
    expect(EPC, 32'hFFFFFFFF, 32'h6000_0040, "EPC captured");
    expect(STATUS, 32'h1, 0, "IE cleared on entry");
    chkreq(0, "IE cleared");
    wrr(EPC, 32'h1234_5678);
    expect(EPC, 32'hFFFFFFFF, 32'h6000_0040, "EPC not writable");
    // ISR clears UATX in Cause (write 0 to bit 11, keep bit 10)
    wrr(CAUSE, 32'h0000_0400);
    expect(CAUSE, 32'h0000_FC00, 32'h0000_0400, "Cause write clears only bit 11");
    wrr(STATUS, 32'h0000_0801);
    chkreq(0, "UARX pending but masked");
    wrr(STATUS, 32'h0000_0C01);
    chkreq(1, "UARX now unmasked");
    wrr(CAUSE, 32'h0); wrr(STATUS, 32'h0);
    expect(CAUSE, 32'h0000_FC00, 0, "Cause cleared");
    // timer: Compare = Count + 6 -> Cause bit 15
    rdr(COUNT, v); wrr(COMPARE, v + 6);
    repeat(8) @(negedge clk);
    expect(CAUSE, 32'h0000_8000, 32'h0000_8000, "timer fired at Count==Compare");
    wrr(STATUS, 32'h0000_8001); chkreq(1, "timer request");
    wrr(COMPARE, 32'hFFFF);
    expect(CAUSE, 32'h0000_8000, 0, "Compare write clears timer bit");
    chkreq(0, "timer cleared");
    // pf_frame / gp_done map to bits 13 / 12
    wrr(STATUS, 0); pulse(2); pulse(3);
    expect(CAUSE, 32'h0000_3000, 32'h0000_3000, "pf_frame/gp_done latched");
`ifdef FORCE_FAIL
    errs = errs + 1; $display("ERROR forced failure (FORCE_FAIL defined)");
`endif
    $display("COP0150_tb: ERRORS: %0d", errs);
    if (errs == 0) $display("PASS: COP0150_tb"); else $display("FAIL: COP0150_tb (%0d errors)", errs);
    $finish;
  end
endmodule
