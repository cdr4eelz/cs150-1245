//----------------------------------------------------------------------
// Module: LineEngineTestbench.v
// This module tests the line engine by
// drawing a few example lines
//----------------------------------------------------------------------

`timescale 1ns / 100ps

module LineEngineTestbench;
    parameter SCANLINERUNNER = 1, LITTLEWORDIAN = 1;

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  Clock, rst;
    initial Clock = 0;
    always #(HalfCycle) Clock= ~Clock;

    wire            LE_ready;
    reg             LE_color_valid;
    reg  [ 31:0]    LE_color;   // 8-bits zeros then 8-bit each for RGB
    reg             LE_x0_valid;
    reg             LE_y0_valid;
    reg             LE_x1_valid;
    reg             LE_y1_valid;
    reg  [  9:0]    LE_point;
    reg             LE_trigger; // Trigger signal - line engine should start drawing
    reg  [ 31:0]    LE_frame;   // Frame base (clipped to multiple of 0x0040_0000)
    
    localparam SLR_LE       = 0;
    localparam  SLR__CNT = 1;
    localparam WATCH_NAME = "line";
    `include "util_gwatch.vh"

    LineEngine #(
        .SCANLINERUNNER(SCANLINERUNNER),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) DUT (
        .clk(Clock),
        .rst(rst),
        .caf_full(caf_full),
        .wdf_full(wdf_full),
        .caf_addr(caf_addr),
        .caf_wren(caf_wren),
        .wdf_data(wdf_data),
        .wdf_mask(wdf_mask),
        .wdf_wren(wdf_wren),
        .LE_ready(LE_ready),
        .LE_color_valid(LE_color_valid),
        .LE_color(LE_color),
        .LE_x0_valid(LE_x0_valid),
        .LE_y0_valid(LE_y0_valid),
        .LE_x1_valid(LE_x1_valid),
        .LE_y1_valid(LE_y1_valid),
        .LE_point(LE_point),
        .LE_trigger(LE_trigger),
        .LE_frame(LE_frame),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_LE]                    ),
        .SLR_valid(SLRs_valid           [SLR_LE]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_row       (SLRs_row       [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_LE*10)+ 9:(SLR_LE*10)] )
    );

    initial begin
        @(posedge Clock);
        caf_full = 1'b0;
        wdf_full = 1'b0;
        LE_color_valid = 1'b0;
        LE_x0_valid = 1'b0;
        LE_y0_valid = 1'b0;
        LE_x1_valid = 1'b0;
        LE_y1_valid = 1'b0;
        LE_trigger = 1'b0;
        rst = 1'b1;
        #(10*Cycle);
        rst = 1'b0;
        #(Cycle);
//      $monitor("R:%b T:%b (%0d,%0d) W:%b.%b", LE_ready, LE_trigger, x,y, caf_wren,wdf_wren);
$display("LineEngine: Fake memory/SLR...");
        drawLine(   2,   4,    10,   6,  32'h11_7F_00_00);
        drawLine(   0,   0,  1023, 767,  32'h22_7F_00_00);
        drawLine(1000, 700,     0,   0,  32'h33_7F_00_00);
        drawLine( 500, 700,     0,   0,  32'h44_7F_00_00);
        drawLine(   0,   0,   400, 652,  32'h55_7F_00_00);
        drawLine( 200, 200,   100, 500,  32'h66_7F_00_FF);

        #(10*Cycle);
$display("LineEngine: Done.");
        $finish();
    end

    task drawLine;
        input [9:0] x0;
        input [9:0] y0;
        input [9:0] x1;
        input [9:0] y1;
        input [31:0] color;
    begin
        $display("le-TB: Wait...");
        #1;
        @(posedge Clock);
        while (!LE_ready) #(Cycle); // wait for LE_ready
        @(posedge Clock); #1;
        LE_color = color;
        LE_color_valid = 1'b1;
        @(posedge Clock); #1;
        LE_color_valid = 1'b0;
        LE_color = 32'bz;
        LE_point = x0;
        LE_x0_valid = 1'b1;
        @(posedge Clock); #1;
        LE_x0_valid = 1'b0;
        LE_point = y0;
        LE_y0_valid = 1'b1;
        @(posedge Clock); #1;
        LE_y0_valid = 1'b0;
        LE_x1_valid = 1'b1;
        LE_point = x1;
        @(posedge Clock); #1;
        LE_x1_valid = 1'b0;
        LE_y1_valid = 1'b1;
        LE_point = y1;
        LE_frame = 32'h1040_0000;
        LE_trigger  = 1'b1;
        @(posedge Clock); #1;
        $display("le-TB: TRIG (%0d,%0d)-=>(%0d,%0d) [%h,%h]-=>[%h,%h] color=%h frame=%h",
                x0,y0, x1,y1, x0,y0, x1,y1, color, LE_frame);
        LE_point = 32'bz;
        LE_frame = 32'bz;
        LE_y1_valid = 1'b0;
        LE_trigger  = 1'b0;
        @(posedge Clock);
        while (!LE_ready) begin
            #1;
            @(posedge Clock);
        end
        $display("le-TB: Done. (%0d,%0d)-=>(%0d,%0d) [%h,%h]-=>[%h,%h] color=%h",
                 x0,y0, x1,y1, x0,y0, x1,y1, color);
    end endtask

endmodule
