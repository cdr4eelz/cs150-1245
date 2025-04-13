//----------------------------------------------------------------------
// Module: FrameFillerTestbench.v
// This module tests the fill engine.
//----------------------------------------------------------------------

`timescale 1ns / 1ps

module FrameFiller_tb;
    parameter SCANLINERUNNER = 1, LITTLEWORDIAN = 0;

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  Clock, rst;
    initial Clock = 0;
    always #(HalfCycle) Clock= ~Clock;

    wire            FF_ready;
    reg             FF_valid; // Trigger signal - fill engine should start drawing
    reg  [ 31:0]    FF_color; // 8-bits zeros then 8-bit each for RGB
    reg  [ 31:0]    FF_frame; // Frame base (clipped to multiple of 0x0040_0000)

    localparam SLR_FF       = 0;
    localparam  SLR__CNT = 1;
    localparam WATCH_NAME = "fill";
    `include "util_gwatch.vh"

    FrameFiller #(
        .SCANLINERUNNER(SCANLINERUNNER)
    ) DUT (
        .clk(Clock),
        .rst(rst),
    //Fill control <=> CPU:
        .FF_ready(FF_ready),
        .FF_valid(FF_valid),
        .FF_color(FF_color),
        .FF_frame(FF_frame),
    //DDR FIFOs (write-only):
        .caf_full(caf_full),
        .caf_wren(caf_wren),
        .caf_addr(caf_addr),
        .wdf_full(wdf_full),
        .wdf_wren(wdf_wren),
        .wdf_data(wdf_data),
        .wdf_mask(wdf_mask),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_FF]                    ),
        .SLR_valid(SLRs_valid           [SLR_FF]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_row       (SLRs_row       [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_FF*10)+ 9:(SLR_FF*10)] )
    );

    initial begin
        #(Cycle);
        @(posedge Clock);
        caf_full = 1'b1;
        wdf_full = 1'b1;
        FF_valid = 1'b0;
        rst = 1'b1;
        #(10*Cycle);
        rst = 1'b0;
        caf_full = 1'b0;
        wdf_full = 1'b0;

$display("FrameFiller: Fake memory/SLR...");
        fillFrame( 32'h00_7F2211, 32'h1040_0000 );

        #(10*Cycle);
$display("FrameFiller: Done.");
        $finish();
    end

    task fillFrame;
        input [31:0] color;
        input [31:0] framebase;
    begin
        @(posedge Clock);
$display("fill-TB: Wait...");
        while (!FF_ready) #(Cycle); // wait for FF_ready
        #1;
        FF_color = color;
        FF_frame = framebase;
        FF_valid = 1'b1;
$display("fill-TB: color=%h  frame=%h", FF_color, FF_frame);
        @(posedge Clock);
        #1;
        FF_valid = 1'b0;
        FF_color = 32'bz;
        FF_frame = 32'bz;
        @(posedge Clock);
        while (!FF_ready) begin
            #1;
            @(posedge Clock);
        end
$display("fill-TB: Done.");
    end endtask

endmodule
