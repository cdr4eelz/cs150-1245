//----------------------------------------------------------------------
// Module: FrameFillerTestbench.v
// This module tests the fill engine.
//----------------------------------------------------------------------

`define MODELSIM 1
`timescale 1ns / 1ps

module FrameFillerTestbench();

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
    // FIFO connections
    reg             af_full;
    wire            af_wr_en;
    wire [ 30:0]    af_addr_din;
    reg             wdf_full;
    wire            wdf_wr_en;
    wire [ 15:0]    wdf_mask_din;
    wire [127:0]    wdf_din;


    wire [  9:0]    x, y;
    reg  [  2:0]    mask;

    always@(*) begin
        if(af_wr_en) begin
            if(wdf_mask_din[15:12] == 4'h0) mask = 3'h0;
            else if(wdf_mask_din[11:8] == 4'h0) mask = 3'h1;
            else if(wdf_mask_din[7:4] == 4'h0) mask = 3'h2;
            else if(wdf_mask_din[3:0] == 4'h0) mask = 3'h3;
            else mask = 3'h0;
        end else begin
            if(wdf_mask_din[15:12] == 4'h0) mask = 3'h4;
            else if(wdf_mask_din[11:8] == 4'h0) mask = 3'h5;
            else if(wdf_mask_din[7:4] == 4'h0) mask = 3'h6;
            else if(wdf_mask_din[3:0] == 4'h0) mask = 3'h7;
            else mask = 3'h0;
        end
    end

    assign x = {af_addr_din[8:2], mask};
    assign y = af_addr_din[18:9];

    FrameFiller DUT (
        .clk(Clock),
        .rst(rst),
        .af_full(af_full),
        .af_wr_en(af_wr_en),
        .af_addr_din(af_addr_din),
        .wdf_full(wdf_full),
        .wdf_wr_en(wdf_wr_en),
        .wdf_din(wdf_din),
        .wdf_mask_din(wdf_mask_din),
        .FF_ready(FF_ready),
        .FF_valid(FF_valid),
        .FF_color(FF_color),
        .FF_frame(FF_frame)
    );

    initial begin
        #(Cycle);
        @(posedge Clock);
        {af_full, wdf_full} = {2{1'b1}};
        {FF_valid, FF_color, FF_frame} = 0;
        rst = 1'b1;
        #(10*Cycle);
        rst = 1'b0;
        {af_full, wdf_full} = {2{1'b0}};
        #(Cycle);
        fillFrame( 32'h00_7F_22_11, 32'h1040_0000 );
    end

    task fillFrame;
        input [31:0] color;
        input [31:0] framebase;
    begin
        @(posedge Clock);
$display("fill-TB: Wait...");
        while (!FF_ready) #(Cycle); // wait for FF_ready
        FF_color = color;
        FF_frame = framebase;
        FF_valid = 1'b1;
$strobe("fill-TB: color=%0h  frame=%0h", FF_color, FF_frame);
        #(Cycle);
        FF_valid = 1'b0;
        FF_color = 32'bz;
        FF_frame = 32'bz;
        while (!FF_ready) begin
            if (wdf_wr_en && wdf_mask_din != 16'hFFFF) begin
$display("fill-TB: %4d %4d", x, y);
            end
            #(Cycle);
        end
$display("fill-TB: Done.");
    end endtask

endmodule
