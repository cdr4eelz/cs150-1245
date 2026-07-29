//----------------------------------------------------------------------
// Module: ElipseEngineTestbench.v
// This module tests the elipse engine by
// drawing a few example elipses
//----------------------------------------------------------------------

`timescale 1ns / 100ps

module ElipseEngineTestbench;
    parameter SCANLINERUNNER = 1, LITTLEWORDIAN = 1;

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  Clock, rst;
    initial Clock = 0;
    always #(HalfCycle) Clock= ~Clock;

    wire            EL_ready;
    reg             EL_color_valid;
    reg  [ 31:0]    EL_color;   // 8-bits zeros then 8-bit each for RGB
    reg             EL_xc_valid;
    reg             EL_yc_valid;
    reg             EL_a_valid;
    reg             EL_b_valid;
    reg  [  9:0]    EL_point;
    reg             EL_trigger; // Trigger signal - elipse engine should start drawing
    reg  [ 31:0]    EL_frame;   // Frame base (clipped to multiple of 0x0040_0000)
    
    localparam SLR_EL       = 0;
    localparam  SLR__CNT = 1;
    localparam WATCH_NAME = "elipse";
    `include "util_gwatch.vh"

    ElipseEngine #(
//        .SCANLINERUNNER(SCANLINERUNNER),
//        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) DUT (
        .clk(Clock),
        .rst(rst),

//        .caf_full(caf_full),
//        .wdf_full(wdf_full),
//        .caf_addr(caf_addr),
//        .caf_wren(caf_wren),
//        .wdf_data(wdf_data),
//        .wdf_mask(wdf_mask),
//        .wdf_wren(wdf_wren),

        .EL_ready(      EL_ready),
        .EL_color_valid(EL_color_valid),
        .EL_color(      EL_color),
        .EL_xc_valid(   EL_xc_valid),
        .EL_yc_valid(   EL_yc_valid),
        .EL_a_valid(    EL_a_valid),
        .EL_b_valid(    EL_b_valid),
        .EL_point(      EL_point),
        .EL_trigger(    EL_trigger),
        .EL_frame(      EL_frame),

    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_EL]                    ),
        .SLR_valid(SLRs_valid           [SLR_EL]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_row       (SLRs_row       [(SLR_EL*10)+ 9:(SLR_EL*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_EL*10)+ 9:(SLR_EL*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_EL*10)+ 9:(SLR_EL*10)] )
   );

    initial begin
        @(posedge Clock);
        caf_full = 1'b0;
        wdf_full = 1'b0;
        EL_color_valid = 1'b0;
        EL_xc_valid = 1'b0;
        EL_yc_valid = 1'b0;
        EL_a_valid = 1'b0;
        EL_b_valid = 1'b0;
        EL_trigger = 1'b0;
        rst = 1'b1;
        #(10*Cycle);
        rst = 1'b0;
        #(Cycle);
//      $monitor("R:%b T:%b (%0d,%0d) W:%b.%b", EL_ready, EL_trigger, x,y, caf_wren,wdf_wren);
$display("ElipseEngine: Fake memory/SLR...");
        //drawElipse( 200, 200,    25,  02,  32'h00_7F_00_00); // SW- HW-

        //drawElipse(  10,  10,     5,   5,  32'h00_7F_00_00); // SW+ HW+
        //drawElipse( 100, 100,    50,  50,  32'h00_7F_00_00);
        //drawElipse( 200, 200,    20,  40,  32'h00_7F_00_00); // SW+ HW+
        //drawElipse( 200, 500,    40,  20,  32'h00_7F_00_00); // SW+ HW+
        //drawElipse( 125, 125,    20,   5,  32'h22_7F_00_00);
        //drawElipse( 400, 400,    40,  20,  32'h33_7F_00_00); // Odd shape
        //drawElipse( 400, 400,    10,  20,  32'h44_7F_00_00);
        drawElipse( 200, 300,   100, 100,  32'h55_7F_00_00);

        #(10*Cycle);
$display("ElipseEngine: Done.");
        $finish();
    end

    task drawElipse;
        input [9:0] xc;
        input [9:0] yc;
        input [9:0] a;
        input [9:0] b;
        input [31:0] color;
    begin
        $display("el-TB: Wait...");
        #1;
        @(posedge Clock);
        while (!EL_ready) #(Cycle); // wait for EL_ready
        @(posedge Clock); #1;
        EL_color = color;
        EL_color_valid = 1'b1;
        @(posedge Clock); #1;
        EL_color_valid = 1'b0;
        EL_color = 32'bz;
        EL_point = xc;
        EL_xc_valid = 1'b1;
        @(posedge Clock); #1;
        EL_xc_valid = 1'b0;
        EL_point = yc;
        EL_yc_valid = 1'b1;
        @(posedge Clock); #1;
        EL_yc_valid = 1'b0;
        EL_a_valid = 1'b1;
        EL_point = a;
        @(posedge Clock); #1;
        EL_a_valid = 1'b0;
        EL_b_valid = 1'b1;
        EL_point = b;
        EL_frame = 32'h1040_0000;
        EL_trigger  = 1'b1;
        @(posedge Clock); #1;
        $display("el-TB: TRIG (%0d,%0d)-=>(%0d,%0d) [%h,%h]-=>[%h,%h] color=%h frame=%h",
                xc,yc, a,b, xc,yc, a,b, color, EL_frame);
        EL_point = 32'bz;
        EL_frame = 32'bz;
        EL_b_valid = 1'b0;
        EL_trigger  = 1'b0;
        @(posedge Clock);
        while (!EL_ready) begin
            #1;
            @(posedge Clock);
        end
        $display("el-TB: Done. (%0d,%0d)-=>(%0d,%0d) [%h,%h]-=>[%h,%h] color=%h",
                 xc,yc, a,b, xc,yc, a,b, color);
    end endtask

endmodule
