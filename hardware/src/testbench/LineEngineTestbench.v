//----------------------------------------------------------------------
// Module: LineEngineTestbench.v
// This module tests the line engine by
// drawing a few example lines
//----------------------------------------------------------------------

`define MODELSIM 1
`timescale 1ns / 1ps

module LineEngineTestbench;

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
    // FIFO connections
    reg             af_full;
    reg             wdf_full;
//  wire [  2:0]    af_cmd_din;
    wire [ 30:0]    af_addr_din;
    wire            af_wr_en;
    wire [127:0]    wdf_din;
    wire [ 15:0]    wdf_mask_din;
    wire            wdf_wr_en;


    wire [  9:0]    x, y, xdiff, ydiff;
    reg  [  2:0]    mask;
//  assign af_cmd_din = 3'b000; //WRITE

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

    LineEngine DUT (
        .clk(Clock),
        .rst(rst),
        .af_full(af_full),
        .wdf_full(wdf_full),
        .af_addr_din(af_addr_din),
        .af_wr_en(af_wr_en),
        .wdf_din(wdf_din),
        .wdf_mask_din(wdf_mask_din),
        .wdf_wr_en(wdf_wr_en),
        .LE_ready(LE_ready),
        .LE_color_valid(LE_color_valid),
        .LE_color(LE_color),
        .LE_x0_valid(LE_x0_valid),
        .LE_y0_valid(LE_y0_valid),
        .LE_x1_valid(LE_x1_valid),
        .LE_y1_valid(LE_y1_valid),
        .LE_point(LE_point),
        .LE_trigger(LE_trigger),
        .LE_frame(LE_frame)
    );

    initial begin
        @(posedge Clock);
        af_full = 1'b0;
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
        drawLine(10'd0, 10'd0, 10'd1023, 10'd767, 32'h00_7F_00_00);
        // drawLine(10'd1000, 10'd700, 10'd0, 10'd0, 32'h00_7F_00_00);
        // drawLine(10'd500, 10'd700, 10'd0, 10'd0, 32'h00_7F_00_00);
        // drawLine(10'd0, 10'd0, 10'd400, 10'd652, 32'h00_7F_00_00);
    end

    task drawLine;
        input [9:0] x0;
        input [9:0] y0;
        input [9:0] x1;
        input [9:0] y1;
        input [31:0] color;
    begin
        while (!LE_ready) #(Cycle); // wait for LE_ready
        LE_color = color;
        LE_color_valid = 1'b1;
        #(Cycle);
        LE_color_valid = 1'b0;
        LE_color = 32'bz;
        LE_point = x0;
        LE_x0_valid = 1'b1;
        #(Cycle);
        LE_x0_valid = 1'b0;
        LE_point = y0;
        LE_y0_valid = 1'b1;
        #(Cycle);
        LE_y0_valid = 1'b0;
        LE_x1_valid = 1'b1;
        LE_point = x1;
        #(Cycle);
        LE_x1_valid = 1'b0;
        LE_y1_valid = 1'b1;
        LE_point = y1;
        LE_frame = 32'h1040_0000;
        LE_trigger  = 1'b1;
        #(Cycle);
        LE_point = 32'bz;
        LE_frame = 32'bz;
        LE_y1_valid = 1'b0;
        LE_trigger  = 1'b0;
        #(Cycle);
        while (!LE_ready) begin
            if (wdf_wr_en && wdf_mask_din != 16'hFFFF) begin
                $display("%4d %4d", x, y);
            end
            #(Cycle);
        end
    end endtask

endmodule
