`timescale 1ns/1ps
`include "tuntap.vh"
// Exercises the PRNG at MMIO 0x80000080 (addra word 0x020) through cpu/MemMapIO.v:
// reads change, back-to-back reads are consecutive LFSR states, a store reseeds
// (0 -> 1), reseed is repeatable, byte store reseeds, a store elsewhere does not,
// addra[5:0] aliasing, and the cycle counter still works.
//   +vcd=<file>   dump waves;   -DFORCE_FAIL  inject one error
module MemMapIO_prng_tb;
  reg clk=0, rst=1, stall=0, ena=0; reg [11:0] addra=0; reg [3:0] wea=0; reg [31:0] dina=0;
  wire [31:0] douta; `BUS_RVA_type(8) RX, TX;
  wire pf_v,gp_vc,gp_vf; wire [31:0] pf_w,gp_wc,gp_wf;
  MemMapIO #(.COLT45_SHAKE(0)) dut(.clk(clk),.rst(rst),.stall(stall),.ena(ena),.addra(addra),.wea(wea),.dina(dina),.douta(douta),
     .RVa_RX(RX),.RVa_TX(TX),.pf_vframe(pf_v),.gp_vcode(gp_vc),.gp_vframe(gp_vf),.pf_wframe(pf_w),.gp_wcode(gp_wc),.gp_wframe(gp_wf),
     .gp_rcode(32'h0),.pf_status(16'h0),.gp_status(16'h0));
  always #5 clk=~clk;
  localparam [31:0] M=32'h80200003;
  function [31:0] nxt(input [31:0] s); nxt = s[0] ? ((s>>1)^M) : (s>>1); endfunction
  // step index (0..7) of v in the sequence starting at s, or -1
  function integer pos(input [31:0] s, input [31:0] v);
    integer k; reg [31:0] t;
    begin pos=-1; t=s; for(k=0;k<8;k=k+1) begin if(t==v && pos<0) pos=k; t=nxt(t); end end
  endfunction
  integer errs=0; reg [31:0] r1,r2,r3; reg [8*256-1:0] fn;
  task rd(input [11:0] a, output [31:0] v); begin @(negedge clk); ena=1; addra=a; wea=0; @(negedge clk); ena=0; v=douta; end endtask
  task wr(input [11:0] a, input [3:0] m, input [31:0] d); begin @(negedge clk); ena=1; addra=a; wea=m; dina=d; @(negedge clk); ena=0; wea=0; end endtask
  task err(input [8*48-1:0] msg); begin errs=errs+1; $display("ERROR %0s", msg); end endtask
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, MemMapIO_prng_tb); end
    repeat(4) @(negedge clk); rst=0; repeat(3) @(negedge clk);
    rd(12'h020,r1); rd(12'h020,r2); rd(12'h020,r3);
    $display("3 reads @0x80000080: %h %h %h", r1,r2,r3);
    if (r1===r2 || r2===r3) err("consecutive reads identical (PRNG stuck/in reset?)");
    if (^r1===1'bx) err("read returned X");
    @(negedge clk); ena=1; addra=12'h020; @(negedge clk); r1=douta; @(negedge clk); r2=douta; ena=0;
    $display("back-to-back: %h %h", r1, r2);
    if (r2!==nxt(r1)) err("back-to-back reads not consecutive LFSR states");
    wr(12'h020,4'hF,32'hDEADBEEF); rd(12'h020,r2);
    $display("after sw 0xDEADBEEF: read %h (step %0d from seed)", r2, pos(32'hDEADBEEF,r2));
    if (pos(32'hDEADBEEF,r2)<0) err("store did not reseed");
    wr(12'h020,4'hF,32'h0); rd(12'h020,r2);
    $display("after sw 0: read %h (step %0d from seed 1)", r2, pos(32'h1,r2));
    if (pos(32'h1,r2)<0) err("seed 0 not mapped to 1");
    wr(12'h020,4'hF,32'hCAFEF00D); rd(12'h020,r1); wr(12'h020,4'hF,32'hCAFEF00D); rd(12'h020,r2);
    $display("reseed 0xCAFEF00D twice, same timing: %h %h", r1, r2);
    if (r1!==r2) err("reseed not repeatable");
    wr(12'h020,4'h1,32'h000000AB); rd(12'h020,r2);
    $display("byte store 0xAB: read %h (step %0d)", r2, pos(32'hAB,r2));
    if (pos(32'hAB,r2)<0) err("byte store did not reseed");
    wr(12'h020,4'hF,32'h11111111); wr(12'h006,4'hF,32'h0); rd(12'h020,r2);
    $display("store to 0x80000018 after seeding 0x11111111: read %h (step %0d)", r2, pos(32'h11111111,r2));
    if (pos(32'h11111111,r2)<0) err("store to another MMIO address disturbed the PRNG");
    wr(12'h0A0,4'hF,32'h55555555); rd(12'h0A0,r1);
    $display("alias addra=0x0A0 (0x80000280): seeded 0x55555555, read %h", r1);
    if (pos(32'h55555555,r1)<0) err("addra[5:0] alias of PRNG did not behave the same");
    rd(12'h004,r1); rd(12'h004,r2); $display("cycle counter reads %0d %0d", r1, r2);
    if (!(r2>r1)) err("cycle counter not increasing");
`ifdef FORCE_FAIL
    err("forced failure (FORCE_FAIL defined)");
`endif
    $display("MemMapIO_prng_tb: ERRORS: %0d", errs);
    if (errs==0) $display("PASS: MemMapIO_prng_tb"); else $display("FAIL: MemMapIO_prng_tb (%0d errors)", errs);
    $finish;
  end
endmodule
