// Memory150_ddr_tb: self-checking test of the CPU-side cache + MIG + Micron DDR2 model path.
//
// Uses the course clock/memory scaffolding (src/testbench/base_clock.vh, base_mem.vh:
// PLL/BUFGs, Memory150 with SIM_ONLY=1, mt4htf3264hy DDR2 SODIMM model) but drives the
// caches with its own tasks instead of cachetesttasks.vh: requests are presented on the
// negedge of cpu_clk_g and held while stalled, the way StageF/StageMW do. (The original
// Memory150TestBench changes its inputs right at @(posedge cpu_clk_g), which races with
// the Cache's posedge sampling; under Icarus the cache never sees a request.)
//
// Checks: write-through + read-miss fill (dcache), icache fill from DDR written by dcache,
// read hits (no stall), byte-masked writes (hit and miss), same-index conflict eviction,
// and a random write/read pass against a shadow memory. Prints PASS / FAIL.
`timescale 1ns/1ps
module Memory150_ddr_tb;
    parameter LITTLEWORDIAN = 0;
    parameter CPU_FREQ  = 50_000_000;
    parameter HalfCycle = 5;          // 100 MHz board clock
`include "base_clock.vh"
`include "base_mem.vh"

`ifndef NRANDOM
  `define NRANDOM 100
`endif
    localparam MAX_STALL = 2000;

    reg         d_re, i_re;
    reg  [ 3:0] d_we;
    reg  [31:0] d_addr, i_addr, d_din;
    assign dcache_re = d_re,   icache_re = i_re;
    assign dcache_we = d_we,   icache_we = 4'b0;
    assign dcache_addr = d_addr, icache_addr = i_addr;
    assign dcache_din = d_din, icache_din = 32'b0;
    assign video_ready = 1'b0;
    assign pf_vframe = 1'b0, gp_vcode = 1'b0, gp_vframe = 1'b0;
    assign pf_wframe = 32'b0, gp_wcode = 32'b0, gp_wframe = 32'b0;

    integer errors = 0, checks = 0, stalls = 0, misses = 0, hits = 0;
    integer seed = 1;
    reg [31:0] got;
    integer    nst;

    // shadow of a 64 KB window at 0x1000_0000 (16K words)
    reg [31:0] shadow [0:16383];
    reg        known  [0:16383];
    integer k;

    // One dcache/icache access: present at negedge, hold through stalls, sample after.
    task access;
        input        icache;
        input [31:0] addr;
        input [ 3:0] we;
        input [31:0] din;
        output [31:0] dout;
        output integer nstall;
    begin
        @(negedge cpu_clk_g);
        if (icache) begin i_addr = addr; i_re = 1; end
        else begin d_addr = addr; d_re = (we == 0); d_we = we; d_din = din; end
        @(posedge cpu_clk_g); #1;
        nstall = 0;
        while (icache ? i_stall : d_stall) begin
            @(posedge cpu_clk_g); #1;
            nstall = nstall + 1;
            if (nstall > MAX_STALL) begin
                $display("FAIL: stall timeout addr=%h icache=%0d", addr, icache);
                $finish;
            end
        end
        dout = icache ? icache_dout : dcache_dout;
        @(negedge cpu_clk_g);
        i_re = 0; d_re = 0; d_we = 0;
        stalls = stalls + nstall;
    end
    endtask

    task dwrite(input [31:0] addr, input [3:0] we, input [31:0] din);
        integer i;
    begin
        access(0, addr, we, din, got, nst);
        k = addr[15:2];
        if (addr[31:16] == 16'h1000) begin
            for (i = 0; i < 4; i = i + 1)
                if (we[i]) shadow[k][8*i +: 8] = din[8*i +: 8];
            known[k] = 1;
        end
    end
    endtask

    // read + compare; expect_hit: 1 must hit, 0 must miss, -1 don't care
    task check_read(input icache, input [31:0] addr, input [31:0] exp, input integer expect_hit);
    begin
        access(icache, addr, 4'b0, 32'b0, got, nst);
        checks = checks + 1;
        if (nst == 0) hits = hits + 1; else misses = misses + 1;
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL: %s read %h = %h, expected %h (stalls %0d)", icache ? "I" : "D", addr, got, exp, nst);
        end else if (expect_hit == 1 && nst != 0) begin
            errors = errors + 1;
            $display("FAIL: %s read %h expected a hit, stalled %0d cycles", icache ? "I" : "D", addr, nst);
        end else if (expect_hit == 0 && nst == 0) begin
            errors = errors + 1;
            $display("FAIL: %s read %h expected a miss, did not stall", icache ? "I" : "D", addr);
        end
    end
    endtask

    integer i, t0, t1;
    reg [31:0] a, v;
    reg [3:0]  m;
    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("Memory150_ddr_tb.vcd"); $dumpvars(0, Memory150_ddr_tb); end
        $timeformat(-9, 0, " ns", 10);
        d_re = 0; i_re = 0; d_we = 0; d_addr = 0; i_addr = 0; d_din = 0;
        for (i = 0; i < 16384; i = i + 1) known[i] = 0;
        t0 = $time;
        BaseClockReset();
        $display("DDR calibrated + reset released at %t", $time);

        // 1. write-through, then read-miss fill, then hit
        dwrite(32'h1000_0000, 4'hF, 32'hDEADBEEF);
        dwrite(32'h1000_0004, 4'hF, 32'h01234567);
        check_read(0, 32'h1000_0000, 32'hDEADBEEF, 0);
        check_read(0, 32'h1000_0004, 32'h01234567, 1);
        check_read(0, 32'h1000_0000, 32'hDEADBEEF, 1);
        // 2. icache fills the same line from DDR
        check_read(1, 32'h1000_0004, 32'h01234567, 0);
        check_read(1, 32'h1000_0000, 32'hDEADBEEF, 1);
        // 3. fill all 8 words of a line, read back through both caches
        for (i = 0; i < 8; i = i + 1) dwrite(32'h1000_0100 + 4*i, 4'hF, 32'hA5000000 + i*32'h01010101);
        for (i = 0; i < 8; i = i + 1) check_read(0, 32'h1000_0100 + 4*i, 32'hA5000000 + i*32'h01010101, i == 0 ? 0 : 1);
        for (i = 7; i >= 0; i = i - 1) check_read(1, 32'h1000_0100 + 4*i, 32'hA5000000 + i*32'h01010101, i == 7 ? 0 : 1);
        // 4. byte-masked write hitting the dcache (line cached above), and one missing it
        dwrite(32'h1000_0104, 4'b0101, 32'h11223344);
        check_read(0, 32'h1000_0104, 32'hA6220144, 1);       // bytes 2,0 from 11223344
        dwrite(32'h1000_0200, 4'hF, 32'hCAFEF00D);
        dwrite(32'h1000_0200, 4'b1000, 32'h77000000);
        check_read(0, 32'h1000_0200, 32'h77FEF00D, 0);
        check_read(1, 32'h1000_0104, 32'hA6010101, 1);   // icache line is stale by design (no snoop)
        // 5. conflict: same index (addr[12:5]), different tag -> evict and refill
        dwrite(32'h1000_2000, 4'hF, 32'h00002000);       // 8 KB above 0x1000_0000
        check_read(0, 32'h1000_2000, 32'h00002000, 0);
        check_read(0, 32'h1000_0000, 32'hDEADBEEF, 0);
        check_read(0, 32'h1000_2000, 32'h00002000, 0);
        t1 = $time;
        $display("directed checks done at %t (%0d checks, %0d errors)", $time, checks, errors);

        // 6. random writes/reads over the 64 KB window, against the shadow
        for (i = 0; i < `NRANDOM; i = i + 1) begin
            a = 32'h1000_0000 | ($random(seed) & 32'h0000_FFFC);
            if (($random(seed) & 3) != 0 || !known[a[15:2]]) begin
                m = known[a[15:2]] ? ($random(seed) & 4'hF) : 4'hF;
                if (m == 0) m = 4'hF;
                v = $random(seed);
                dwrite(a, m, v);
            end else
                check_read(0, a, shadow[a[15:2]], -1);
        end
        // final sweep: every written word through the dcache
        for (i = 0; i < 16384; i = i + 1)
            if (known[i]) check_read(0, 32'h1000_0000 | (i << 2), shadow[i], -1);

        $display("%0d read checks (%0d hits, %0d misses), %0d stall cycles total, sim time %t (%t after reset)",
                 checks, hits, misses, stalls, $time, $time - t0);
        if (errors == 0) $display("PASS: Memory150 DDR2 cache path");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
