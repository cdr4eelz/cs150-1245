`timescale 1ns/1ps

module GraphicsProcessorTestbench();

    reg Clock, Reset;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;

    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;


    reg         rdf_valid;
    reg         af_full;
    reg [127:0] rdf_dout;
    wire        rdf_rd_en;
    wire        af_wr_en;
    wire [30:0] af_addr_din;
//  wire        ready;

    reg         FF_ready;
    wire        FF_valid;
    wire [31:0] FF_color;
    wire [31:0] FF_frame;

    reg         LE_ready;
    wire        LE_color_valid;
    wire [31:0] LE_color;
    wire        LE_x0_valid;
    wire        LE_y0_valid;
    wire        LE_x1_valid;
    wire        LE_y1_valid;
    wire [ 9:0] LE_point;
    wire        LE_trigger;
    wire [31:0] LE_frame;

    wire        GP_ready;
    reg         GP_valid;
    reg  [31:0] GP_frame;
    reg  [31:0] GP_code;
    reg  [ 5:0] GP_proccode;
    wire        GP_interrupt;
//  wire bsel;

    GraphicsProcessor DUT(
        .clk(Clock),
        .rst(Reset),
//      .bsel(bsel), ???What was this to be???
    //DDR FIFOs
        .rdf_valid(rdf_valid),
        .af_full(af_full),
        .rdf_dout(rdf_dout),
        .rdf_rd_en(rdf_rd_en),
        .af_wr_en(af_wr_en),
        .af_addr_din(af_addr_din),
    //LineEngine control signals
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
    //FrameFiller control signals
        .FF_ready(FF_ready),
        .FF_valid(FF_valid),
        .FF_color(FF_color),
        .FF_frame(FF_frame),
    //GraphicsProcessor control signals
        .GP_ready(GP_ready),
        .GP_valid(GP_valid),
        .GP_frame(GP_frame),
        .GP_code(GP_code),
        .GP_procframe(GP_procframe),
        .GP_interrupt(GP_interrupt)
    );

    initial begin
        //TODO put your code here
        $finish();
    end

endmodule
