`timescale 1ns/1ps
// Unit test for base_util/PRNG32LFSR.v (32-bit Galois LFSR, mask 0x80200003).
// Checks: async reset value, cycle-by-cycle match with a reference model,
// never zero, per-bit balance, seed load (incl. 0 -> 1 and all-ones),
// held load, repeatability after reseed, async reset mid-run.
//   +n=<cycles>      cycles to run (default PRNG_CYCLES, 100000)
//   +seq=<file>      also write every value (hex, one per line) to <file>
//   +vcd=<file>      dump waves
//   -DFORCE_FAIL     inject one error (to check the rig's failure detection)
`ifndef PRNG_CYCLES
 `define PRNG_CYCLES 100000
`endif
module PRNG32LFSR_tb;
  reg clk=0, rst_n=0, load=0; reg [31:0] seed=0; wire [31:0] q;
  PRNG32LFSR dut(.clk(clk),.rst_n(rst_n),.load_seed(load),.seed_val(seed),.prng_out(q));
  always #5 clk=~clk;
  localparam [31:0] M=32'h80200003;
  function [31:0] nxt(input [31:0] s); nxt = s[0] ? ((s>>1)^M) : (s>>1); endfunction
  integer errs=0, i, b, f, N, mism=0, zeros_seen=0, lo, hi;
  integer ones[0:31];
  reg [31:0] model, s1[0:15];
  reg [8*256-1:0] fn;
  task chk(input [31:0] exp, input [8*40-1:0] what);
    if (q!==exp) begin errs=errs+1; $display("ERROR %0s: got %h want %h @%0t",what,q,exp,$time); end
  endtask
  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, PRNG32LFSR_tb); end
    if (!$value$plusargs("n=%d",N)) N=`PRNG_CYCLES;
    f=0; if ($value$plusargs("seq=%s", fn)) f=$fopen(fn,"w");
    for(b=0;b<32;b=b+1) ones[b]=0;
    #1 chk(32'hACE12468,"async reset value");
    @(negedge clk); @(negedge clk); chk(32'hACE12468,"held in reset");
    rst_n=1; model=32'hACE12468;
    for(i=0;i<N;i=i+1) begin
      @(negedge clk); model=nxt(model);
      if (q!==model) begin mism=mism+1; if(mism<5) $display("ERROR step %0d got %h want %h",i,q,model); end
      if (q==0) zeros_seen=zeros_seen+1;
      for(b=0;b<32;b=b+1) ones[b]=ones[b]+q[b];
      if (f) $fwrite(f,"%h\n",q);
    end
    if (f) $fclose(f);
    errs=errs+mism+zeros_seen;
    lo=N; hi=0;
    for(b=0;b<32;b=b+1) begin if(ones[b]<lo) lo=ones[b]; if(ones[b]>hi) hi=ones[b]; end
    $display("Ran %0d cycles: model mismatches=%0d zeros=%0d; per-bit ones fraction min %.4f max %.4f",
             N, mism, zeros_seen, lo*1.0/N, hi*1.0/N);
    if (N>=10000 && (lo*1.0/N<0.48 || hi*1.0/N>0.52)) begin errs=errs+1; $display("ERROR bit balance out of 0.48..0.52"); end
    seed=0; load=1; @(negedge clk); load=0; chk(32'h1,"seed 0 -> 1");
    @(negedge clk); chk(nxt(32'h1),"advance after seed 1");
    seed=32'hFFFFFFFF; load=1; @(negedge clk); load=0; chk(32'hFFFFFFFF,"seed FFFFFFFF");
    @(negedge clk); chk(nxt(32'hFFFFFFFF),"advance from FFFFFFFF");
    seed=32'h12345678; load=1; @(negedge clk); @(negedge clk); @(negedge clk); chk(32'h12345678,"load held");
    load=0;
    for(i=0;i<16;i=i+1) begin @(negedge clk); s1[i]=q; end
    load=1; @(negedge clk); load=0;
    for(i=0;i<16;i=i+1) begin @(negedge clk); if(q!==s1[i]) begin errs=errs+1; $display("ERROR repeat seq %0d",i); end end
    #2 rst_n=0; #1 chk(32'hACE12468,"async reset mid-run"); @(negedge clk); rst_n=1;
`ifdef FORCE_FAIL
    errs=errs+1; $display("ERROR forced failure (FORCE_FAIL defined)");
`endif
    $display("PRNG32LFSR_tb: ERRORS: %0d", errs);
    if (errs==0) $display("PASS: PRNG32LFSR_tb"); else $display("FAIL: PRNG32LFSR_tb (%0d errors)", errs);
    $finish;
  end
endmodule
