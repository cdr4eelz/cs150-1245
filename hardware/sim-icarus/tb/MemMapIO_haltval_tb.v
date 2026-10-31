`timescale 1ns/1ps
`include "tuntap.vh"
// Exercises the HaltVal register at MMIO 0x80000084 (addra word 0x021) through cpu/MemMapIO.v:
// reset value 0, store-then-load of several words, value holds across reads, any nonzero wea
// stores the whole dina word (the RTL has no byte-lane masking), stores
// elsewhere (PRNG seed 0x80, ResetCnt 0x18) leave it alone, HaltVal stores do not disturb the
// PRNG sequence at 0x80000080, and a later reset clears it again.
// Stimulus is driven on negedge, the DUT samples on posedge (no #delays).
//   +vcd=<file>   dump waves;   -DFORCE_FAIL  inject one error
module MemMapIO_haltval_tb;
  reg clk=0, rst=1, stall=0, ena=0; reg [11:0] addra=0; reg [3:0] wea=0; reg [31:0] dina=0;
  wire [31:0] douta; `BUS_RVA_type(8) RX, TX;
  wire pf_v,gp_vc,gp_vf; wire [31:0] pf_w,gp_wc,gp_wf;
  MemMapIO #(.COLT45_SHAKE(0)) dut(.clk(clk),.rst(rst),.stall(stall),.ena(ena),.addra(addra),.wea(wea),.dina(dina),.douta(douta),
     .RVa_RX(RX),.RVa_TX(TX),.pf_vframe(pf_v),.gp_vcode(gp_vc),.gp_vframe(gp_vf),.pf_wframe(pf_w),.gp_wcode(gp_wc),.gp_wframe(gp_wf),
     .gp_rcode(32'h0),.pf_status(16'h0),.gp_status(16'h0));
  always #5 clk=~clk;
  localparam [11:0] A_HALT=12'h021, A_PRNG=12'h020, A_RSTCNT=12'h006;
  localparam [31:0] M=32'h80200003;
  function [31:0] nxt(input [31:0] s); nxt = s[0] ? ((s>>1)^M) : (s>>1); endfunction
  // step index (0..15) of v in the LFSR sequence starting at s, or -1
  function integer pos(input [31:0] s, input [31:0] v);
    integer k; reg [31:0] t;
    begin pos=-1; t=s; for(k=0;k<16;k=k+1) begin if(t==v && pos<0) pos=k; t=nxt(t); end end
  endfunction
  integer errs=0, checks=0, i; reg [31:0] r1,r2; reg [8*256-1:0] fn;
  reg [31:0] vals [0:5];
  task rd(input [11:0] a, output [31:0] v); begin @(negedge clk); ena=1; addra=a; wea=0; @(negedge clk); ena=0; v=douta; end endtask
  task wr(input [11:0] a, input [3:0] m, input [31:0] d); begin @(negedge clk); ena=1; addra=a; wea=m; dina=d; @(negedge clk); ena=0; wea=0; end endtask
  task err(input [8*64-1:0] msg); begin errs=errs+1; $display("ERROR %0s", msg); end endtask
  task chk(input [8*64-1:0] what, input [31:0] got, input [31:0] exp);
    begin checks=checks+1;
      if (got!==exp) begin errs=errs+1; $display("ERROR %0s: got %h expected %h", what, got, exp); end
      else $display("ok    %0s: %h", what, got);
    end
  endtask
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, MemMapIO_haltval_tb); end
    vals[0]=32'h00000000; vals[1]=32'hDEADBEEF; vals[2]=32'h12345678; vals[3]=32'hFFFFFFFF;
    vals[4]=32'hA5A5A5A5; vals[5]=32'h00000001;
    repeat(4) @(negedge clk); rst=0; repeat(2) @(negedge clk);
    // reset value
    rd(A_HALT,r1); chk("reset value", r1, 32'h0);
    // store-then-load, full word
    for (i=0;i<6;i=i+1) begin wr(A_HALT,4'hF,vals[i]); rd(A_HALT,r1); chk("sw/lw full word", r1, vals[i]); end
    // value holds across repeated reads and idle cycles
    wr(A_HALT,4'hF,32'hCAFEF00D); rd(A_HALT,r1); repeat(5) @(negedge clk); rd(A_HALT,r2);
    chk("hold: first read", r1, 32'hCAFEF00D); chk("hold: read after idle", r2, 32'hCAFEF00D);
    // back-to-back read (ena held) returns the same value every cycle
    @(negedge clk); ena=1; addra=A_HALT; @(negedge clk); r1=douta; @(negedge clk); r2=douta; ena=0;
    chk("back-to-back read 1", r1, 32'hCAFEF00D); chk("back-to-back read 2", r2, 32'hCAFEF00D);
    // ena=0 with wea set must not write
    @(negedge clk); ena=0; addra=A_HALT; wea=4'hF; dina=32'h0BADF00D; @(negedge clk); wea=0;
    rd(A_HALT,r1); chk("ena=0 store ignored", r1, 32'hCAFEF00D);
    // byte enables: RTL stores the whole dina word for any nonzero wea (no lane masking)
    wr(A_HALT,4'hF,32'h00000000);
    wr(A_HALT,4'b0001,32'hAABBCCDD); rd(A_HALT,r1); chk("wea=0001 stores whole word", r1, 32'hAABBCCDD);
    wr(A_HALT,4'b1000,32'h11223344); rd(A_HALT,r1); chk("wea=1000 stores whole word", r1, 32'h11223344);
    wr(A_HALT,4'b0110,32'h55667788); rd(A_HALT,r1); chk("wea=0110 stores whole word", r1, 32'h55667788);
    wr(A_HALT,4'hF,32'h13579BDF); rd(A_HALT,r1); chk("store-then-load 0x13579BDF", r1, 32'h13579BDF);
    // stores to neighbours leave HaltVal alone
    wr(A_PRNG,4'hF,32'h22222222); rd(A_HALT,r1); chk("PRNG seed store leaves HaltVal", r1, 32'h13579BDF);
    wr(A_RSTCNT,4'hF,32'hFFFFFFFF); rd(A_HALT,r1); chk("ResetCnt store leaves HaltVal", r1, 32'h13579BDF);
    wr(12'h022,4'hF,32'hFFFFFFFF); rd(A_HALT,r1); chk("store to unmapped 0x88 leaves HaltVal", r1, 32'h13579BDF);
    // HaltVal stores do not disturb the PRNG: seed, store HaltVal twice, PRNG still on seed's sequence
    wr(A_PRNG,4'hF,32'hDEADBEEF); wr(A_HALT,4'hF,32'h00000000); wr(A_HALT,4'hF,32'hFFFFFFFF); rd(A_PRNG,r1);
    checks=checks+1;
    if (pos(32'hDEADBEEF,r1)<0) err("HaltVal stores disturbed the PRNG sequence");
    else $display("ok    PRNG after seed 0xDEADBEEF + 2 HaltVal stores: %h (step %0d)", r1, pos(32'hDEADBEEF,r1));
    // and PRNG reads still advance (consecutive LFSR states) with HaltVal holding its value
    @(negedge clk); ena=1; addra=A_PRNG; @(negedge clk); r1=douta; @(negedge clk); r2=douta; ena=0;
    checks=checks+1;
    if (r2!==nxt(r1)) err("PRNG back-to-back reads not consecutive after HaltVal stores");
    else $display("ok    PRNG back-to-back: %h %h", r1, r2);
    rd(A_HALT,r1); chk("HaltVal after PRNG reads", r1, 32'hFFFFFFFF);
    // a later reset clears HaltVal
    @(negedge clk); rst=1; repeat(2) @(negedge clk); rst=0; @(negedge clk);
    rd(A_HALT,r1); chk("cleared by reset", r1, 32'h0);
`ifdef FORCE_FAIL
    err("forced failure (FORCE_FAIL defined)");
`endif
    $display("MemMapIO_haltval_tb: %0d checks, %0d passed, ERRORS: %0d", checks, checks-errs, errs);
    if (errs==0) $display("PASS: MemMapIO_haltval_tb (%0d checks)", checks); else $display("FAIL: MemMapIO_haltval_tb (%0d errors)", errs);
    $finish;
  end
endmodule
