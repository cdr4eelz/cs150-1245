//----------------------------------------------------------------------
// Module: Memory150TestBench.v
// Authors: Dan Yeager, James Parker, Daiwei Li
// This module performs high level cache reads/writes
// which tests Memory150 and DDR2 as well as submodules
// such as the cache, clock crossing FIFOs and request handling.
//
// *** NOTES ***
// To turn off DDR2 info messages (greatly improves sim speed)
//  Set "DEBUG = 0" in src/mig_v3_61/ddr2_model_parameters.vh
//
// Also use sim_only to improve speed: Memory150 #(.SIM_ONLY(1'b1))
//----------------------------------------------------------------------

`timescale 1ns / 1ps

`ifndef MODELSIM
`define MODELSIM 1
`endif

module Memory150TestBench;
    parameter TB_DEBUG_OUT = 1;
    parameter MAX_STALLS  = 50; // simple time-out
    parameter HEARTBEAT = 1000; // 1 unit = 10ns (see $timeformat)

    parameter LITTLEWORDIAN = 0;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)

`include "base_clock.vh"
`include "base_mem.vh"
`include "base_echo.vh"

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
    numFails       = 0;
    readNumD       = 0;
    writeNumD      = 0;
    readNumI       = 0;
    writeNumI      = 0;
    writeNumLine   = 0;
    writeNumPixel  = 0;
    ccDelayCnt     = 0;
    // Inputs:
    CacheResetInputs();

BaseClockReset();

    // 25 combinations of events - for each cache:
    //   1. No Read or Write
    //   2. Read Hit
    //   3. Write Hit
    //   4. Writeback
    //   5. Fetch

    PerformanceCacheExample();

    repeat (10) @( posedge cpu_clk_g ) ;

    ICacheIdleTest_WT();
    ICacheReadHitTest_WT();

    // A few of these are illegal:
    // ICache only written in bios mode,
    // I&D caches should write to same addr.

    if(numFails == 0) begin
        $display(" All tests PASSED ");
    end else begin
        $display(" ** FAIL ** ");
        $display("%d tests failed.", numFails);
    end

    repeat (10) @( posedge cpu_clk_g ) ;
    $finish();
end


    always @ (posedge cpu_clk_g) begin
        if(ccCnt < HEARTBEAT) begin
            ccCnt = ccCnt + 1;
        end else begin
            ccCnt = 0;
            $display("TB: Time = %t", $time);
        end
    end

    task ExampleTest;
    begin
        $display("--- Start Simple Test ---");
        // Try storing a word, no eviction:
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);

        // Try storing again, no hit on write-no-allocate:
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);

        // Not a hit on write-no-allocate:
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);

        // Then cause the row to be evicted
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);

        // now try to read the original data:
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        $display("--- End Simple Test ---");
    end endtask

    task ICacheIdleTest_WT;
    begin
        $display("--------------------------");
        $display("--- Start I$ Idle Test ---");
        $display("--------------------------");
        // Try storing a word and reading it, no eviction:
        // Write (miss)
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        // Read miss
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        // Read hit
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Write (hit)
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
        // Read miss
        SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
        // Write (hit)
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        // Read miss
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Then cause the row to be evicted
        // Write (miss)
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        // and read it out
        // Read miss
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);
        // Read hit
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

        // now try to read the original data:
        // Read miss
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        // Read hit
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        $display("--------------------------");
        $display("---- End I$ Idle Test ----");
        $display("--------------------------");
    end endtask

    task ICacheReadHitTest_WT;
    begin
        $display("------------------------------");
        $display("--- Start I$ Read Hit Test ---");
        $display("------------------------------");

        // Set up data for ICACHE
        SingleCacheWrite(`ICACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`ICACHE, 32'h00000000, 32'h12345678, 1'b0);
        SingleCacheRead(`ICACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Try storing a word and reading it, no eviction:
        // Write (miss)
        DualCacheIreadDwrite(32'h00000000, 32'h12345678, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
        // Read miss
        DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);
        // Read hit
        DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);

        // Write (hit)
        DualCacheIreadDwrite(32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
        // Read miss
        DualCacheRead(32'h00000000, 32'hdeadbeef, 32'h00000000, 32'h12345678);
        // Write (hit)
        DualCacheIreadDwrite(32'h00000000, 32'h12345678, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
        // Read miss
        DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);

        // Then cause the row to be evicted
        // Write (miss)
        DualCacheIreadDwrite(32'h00100000, 32'h12344321, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);

        // and read it out
        // Read miss
        DualCacheRead(32'h00100000, 32'h12344321, 32'h00000000, 32'h12345678);
        // Read hit
        DualCacheRead(32'h00100000, 32'h12344321, 32'h00000000, 32'h12345678);

        // now try to read the original data:
        // Read miss
        DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);
        // Read hit
        DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);

        $display("------------------------------");
        $display("---- End I$ Read Hit Test ----");
        $display("------------------------------");
    end endtask

/* Other examples:
    // instruction store (write same to both)
        DualCacheWrite(32'h00000100, 32'h11223344, 4'b1111, 1'b0,
                        32'h00000100, 32'h11223344, 4'b1111, 1'b0);
    // instruction store (read same from both)
        DualCacheRead(32'h00000100, 32'h11223344,
                        32'h00000100, 32'h11223344);
*/

    // Temp vars for performance cache testing
    localparam
        d1  = 32'hABCDDCBA,
        d2  = 32'h11112222,
        d1e  = 32'h33334444,
        d2e  = 32'h55556666;

    localparam // e for eviction address
        a1   = 32'h00000000,
        a1e  = 32'h00100000,
        a2   = 32'h00010000,
        a2e  = 32'h00110000;

    // Read cache at full speed
    // (requires interleaving of requests and verification)
    // ** hit/miss won't work here
    //    because when we interleave, we reset the cycle counter.
    task PerformanceCacheExample;
    begin
        $display("--- Start Performance Cache Test #1 ---");
        $display("ignore cycle counts here");

        // Request 1
        SetupWrite(`ICACHE, a1, d1, 4'b1111);
        SetupWrite(`DCACHE, a2, d2, 4'b1111);
        // (no prior requests to verify)
        ClockInRequest();

        // Request 2
        SetupWrite(`ICACHE, a1e, d1e, 4'b1111);
        SetupWrite(`DCACHE, a2e, d2e, 4'b1111);
        // Verify 1
        VerifyWrite(`ICACHE, 1'bx);
        VerifyWrite(`DCACHE, 1'bx);
        ClockInRequest();

        // Request 3
        SetupRead(`ICACHE, a1);
        SetupRead(`DCACHE, a2);
        VerifyWrite(`ICACHE, 1'bx);
        VerifyWrite(`DCACHE, 1'bx);
        // (could verify request 2 now)
        ClockInRequest();

        // Request 4
        SetupRead(`ICACHE, a1e);
        SetupRead(`DCACHE, a2e);
        // Verify 3
        // Read miss
        VerifyRead(`ICACHE, d1, 1'bx); //NOTE: Was 0'bx in skeleton
        VerifyRead(`DCACHE, d2, 1'bx); //NOTE: Was 0'bx in skeleton
        ClockInRequest();

        // Request 5
        SetupRead(`ICACHE, a1e);
        SetupRead(`DCACHE, a2e);
        // Verify 4
        // Read miss
        VerifyRead(`ICACHE, d1e, 1'bx); //NOTE: Was 0'bx in skeleton
        VerifyRead(`DCACHE, d2e, 1'bx); //NOTE: Was 0'bx in skeleton
        ClockInRequest();

        // Request 5
        // Verify 4
        // Read hit
        VerifyRead(`ICACHE, d1e, 1'bx);
        VerifyRead(`DCACHE, d2e, 1'bx);

        ClockInRequest();
        $display("--- End Performance Cache Test #1 ---");
    end endtask

endmodule
