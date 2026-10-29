`timescale 1ns/1ps
`include "tuntap.vh"
// MMIO UART + counters path: MemMapIO <-> UARTRVA <-serial-> UART (the "PC" side),
// as wired in MemBank.v. Checks the UART control/data registers (0x80000000..0C),
// both directions of serial traffic, IRQ_TX/IRQ_RX pulses, and the cycle/instruction
// counters (0x80000010/14) incl. instruction count holding during stall and the
// counter reset store (0x80000018).
//   +vcd=<file>   dump waves;   -DFORCE_FAIL  inject one error
module MemMapIO_uart_tb;
  localparam CLK_HZ = 1_000_000, BAUD = 100_000;   // 10 clocks per bit keeps it fast
  reg clk=0, rst=1, stall=0, ena=0; reg [11:0] addra=0; reg [3:0] wea=0; reg [31:0] dina=0;
  wire [31:0] douta; `BUS_RVA_type(8) UARX, UATX;
  wire pf_v,gp_vc,gp_vf; wire [31:0] pf_w,gp_wc,gp_wf;
  wire ser_to_fpga, ser_from_fpga, irq_rx, irq_tx;
  always #5 clk=~clk;

  MemMapIO #(.COLT45_SHAKE(0)) mm(.clk(clk),.rst(rst),.stall(stall),.ena(ena && !stall),.addra(addra),.wea(wea),.dina(dina),.douta(douta),
     .RVa_RX(UARX),.RVa_TX(UATX),.pf_vframe(pf_v),.gp_vcode(gp_vc),.gp_vframe(gp_vf),.pf_wframe(pf_w),.gp_wcode(gp_wc),.gp_wframe(gp_wf),
     .gp_rcode(32'h0),.pf_status(16'h0),.gp_status(16'h0));
  UARTRVA #(.ClockFreq(CLK_HZ), .BaudRate(BAUD)) uartrva(.Clock(clk), .Reset(rst),
     .SIn(ser_to_fpga), .UARX(UARX), .IRQ_RX(irq_rx), .UATX(UATX), .SOut(ser_from_fpga), .IRQ_TX(irq_tx));
  // the far end ("PC")
  reg [7:0] pc_din=0; reg pc_din_valid=0, pc_dout_ready=0; wire pc_din_ready, pc_dout_valid; wire [7:0] pc_dout;
  UART #(.ClockFreq(CLK_HZ), .BaudRate(BAUD)) pc(.Clock(clk), .Reset(rst),
     .DataIn(pc_din), .DataInValid(pc_din_valid), .DataInReady(pc_din_ready),
     .DataOut(pc_dout), .DataOutValid(pc_dout_valid), .DataOutReady(pc_dout_ready),
     .SIn(ser_from_fpga), .SOut(ser_to_fpga));

  integer errs=0, n_irq_rx=0, n_irq_tx=0, k;
  always @(posedge clk) if (!rst) begin n_irq_rx = n_irq_rx + irq_rx; n_irq_tx = n_irq_tx + irq_tx; end
  reg [31:0] r1, r2, c1, i1, c2, i2;
  task rd(input [11:0] a, output [31:0] v); begin @(negedge clk); ena=1; addra=a; wea=0; @(negedge clk); ena=0; v=douta; end endtask
  task wr(input [11:0] a, input [31:0] d); begin @(negedge clk); ena=1; addra=a; wea=4'hF; dina=d; @(negedge clk); ena=0; wea=0; end endtask
  task err(input [8*64-1:0] msg); begin errs=errs+1; $display("ERROR %0s", msg); end endtask
  task poll(input [11:0] a, input integer maxn); integer n; begin
      n=0; rd(a,r1); while (r1[0]!==1'b1 && n<maxn) begin rd(a,r1); n=n+1; end
      if (r1[0]!==1'b1) begin errs=errs+1; $display("ERROR poll of %h never saw 1", a); end
  end endtask
  // FPGA -> PC: send one byte via MMIO and check the PC side gets it
  task fpga_send(input [7:0] b); integer n; begin
      poll(12'h000, 1000);                 // UATX ready
      wr(12'h002, {24'h0, b});
      n=0; pc_dout_ready=1; while (!pc_dout_valid && n<2000) begin @(negedge clk); n=n+1; end
      if (!pc_dout_valid) err("PC side never received a byte");
      else if (pc_dout!==b) begin errs=errs+1; $display("ERROR PC got %h want %h", pc_dout, b); end
      @(negedge clk); pc_dout_ready=0;
  end endtask
  // PC -> FPGA: send one byte from the PC side and read it via MMIO
  task pc_send(input [7:0] b); begin
      @(negedge clk); pc_din=b; pc_din_valid=1; while (!pc_din_ready) @(negedge clk); @(negedge clk); pc_din_valid=0;
      poll(12'h001, 1000);                 // UARX valid
      rd(12'h003, r2);
      if (r2[7:0]!==b) begin errs=errs+1; $display("ERROR MMIO read %h want %h", r2[7:0], b); end
      rd(12'h001, r1);
      if (r1[0]!==1'b0) err("RxValid still set after reading the data register");
  end endtask
  reg [8*256-1:0] fn;
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, MemMapIO_uart_tb); end
    repeat(5) @(negedge clk); rst=0; repeat(30) @(negedge clk);
    rd(12'h001, r1); if (r1!==32'd0) begin errs=errs+1; $display("ERROR RxValid after reset = %h", r1); end
    rd(12'h000, r1); if (r1!==32'd1) begin errs=errs+1; $display("ERROR TxReady after reset = %h", r1); end
    for (k=0;k<4;k=k+1) fpga_send(8'h41 + k*8'h11);       // A R c t
    fpga_send(8'h00); fpga_send(8'hFF);
    pc_send(8'h5A); pc_send(8'hA5); pc_send(8'h00); pc_send(8'hFF);
    $display("UART: FPGA->PC and PC->FPGA bytes done; IRQ_TX pulses=%0d IRQ_RX pulses=%0d", n_irq_tx, n_irq_rx);
    if (n_irq_rx != 4) err("expected 4 IRQ_RX pulses");
    if (n_irq_tx < 6)  err("expected at least 6 IRQ_TX pulses");
    // counters
    wr(12'h006, 0);                         // reset counters
    rd(12'h004, c1); rd(12'h005, i1);
    if (c1 > 4) begin errs=errs+1; $display("ERROR cycle count %0d right after reset store", c1); end
    repeat(10) @(negedge clk);
    stall=1; repeat(20) @(negedge clk); stall=0;
    rd(12'h004, c2); rd(12'h005, i2);
    $display("counters: cycles %0d -> %0d, instrs %0d -> %0d (20 of the cycles stalled)", c1, c2, i1, i2);
    if (c2 - c1 < 30) err("cycle counter did not advance through the stall");
    if ((c2 - c1) - (i2 - i1) < 20) err("instruction counter advanced during stall");
    if (i2 - i1 < 10) err("instruction counter did not advance without stall");
`ifdef FORCE_FAIL
    err("forced failure (FORCE_FAIL defined)");
`endif
    $display("MemMapIO_uart_tb: ERRORS: %0d", errs);
    if (errs==0) $display("PASS: MemMapIO_uart_tb"); else $display("FAIL: MemMapIO_uart_tb (%0d errors)", errs);
    $finish;
  end
  initial begin #50_000_000; $display("FAIL: MemMapIO_uart_tb timeout"); $finish; end
endmodule
