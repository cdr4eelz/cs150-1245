//----------------------------------------------------------------------
// Module: CacheTestBench.v
// Authors: Dan Yeager, James Parker, Daiwei Li
// This module directly tests the cache module
// DDR2 / FIFO requests must be "faked"
//
// *** NOTES ***
//----------------------------------------------------------------------

`timescale 1ns / 1ps

module Cache_tb;
    parameter LITTLEWORDIAN = 0;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)
`include "base_clock.vh"
`include "base_mem.vh"
`include "base_echo.vh"

    parameter TB_DEBUG_OUT = 1;
    parameter MAX_STALLS  = 50; // simple time-out
    parameter HEARTBEAT = 1000; // 1 unit = 10ns

    // Test log variables
    integer numFails,     ccDelayCnt;
    integer readNumD,     writeNumD;
    integer readNumI,     writeNumI;
    integer writeNumLine, writeNumPixel;
    integer ccCnt;
    reg [8*21:0] StrRW; // "read" or "write"

    // Modular cache testing procedures
    `include "cachetesttasks.vh"

initial begin
    $timeformat(-9, 1, " ns", 3);
    // $timeformat [ ( n, p, suffix , min_field_width ) ] ;
    //    units = 1 second ** (-n), n = 0->15, e.g. for n = 9, units = ns
    //    p = digits after decimal point for %t e.g. p = 5 gives 0.00000
    //    suffix for %t (despite timescale directive), ex " ns"
    //    min_field_width is number of character positions for %t */
    //#1;
    // Debugging status variables:
    numFails   = 0;
    readNumD   = 0;
    writeNumD  = 0;
    readNumI   = 0;
    writeNumI  = 0;
    ccDelayCnt = 0;
    // Inputs:
    CacheResetInputs();

BaseClockReset();

    cacheWriteThruTest();
    // cacheAssocFourWay();

    if(numFails == 0) begin
    $display(" All tests PASSED ");
    end else begin
    $display(" ** FAIL ** ");
    $display("%d tests failed.", numFails);
    end

    $finish();
end


    task cacheWriteThruTest;
    begin
        // Try storing a word and reading it, no eviction:
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Then cause the row to be evicted
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);

        // now try to read the original data:
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
    end endtask

    task cacheAssocFourWay;
    begin
        // Store a word into way 1, read it out
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Overwrite it, read it back, then write back the original value
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Store a word into way 2, read it out, and the word from way 1
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Store a word into way 3
        SingleCacheWrite(`DCACHE, 32'h00200000, 32'h12341234, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b1);

        // and read words from ways 1 and 2
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

        // Store a word into way 4
        SingleCacheWrite(`DCACHE, 32'h00300000, 32'h43211234, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b1);

        // and read words from ways 1, 2, and 3
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b1);
    end endtask

    // Simulation takes a long time
    // Provide some info that its not hung:
    always @ (posedge cpu_clk_g) begin
        if(ccCnt < HEARTBEAT) begin
            ccCnt = ccCnt + 1;
        end else begin
            ccCnt = 0;
            $display("TB: Time = %t", $time);
        end
    end

endmodule
