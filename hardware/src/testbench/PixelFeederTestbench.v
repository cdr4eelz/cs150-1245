`timescale 1ns/1ns //NOTE: Modest precision!

`include "cpuglobal.vh"

module PixelFeederTestbench;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 100_000_000;

    reg Clock, Reset;
    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;

    reg clk50_g;
    initial clk50_g = 1;
    always #(HalfCycle*2) clk50_g <= ~clk50_g;

    wire cpu_clk_g = Clock;

reg  rdf_valid, af_full, video_ready;
reg  [127:0] rdf_dout;
wire rdf_rd_en, af_wr_en, video_valid, frame_interrupt;
wire [30:0]  af_addr_din;
wire [23:0]  video;

PixelFeeder DUT (
    .cpu_clk_g(cpu_clk_g), .clk50_g(clk50_g), .rst(Reset),
    .rdf_valid(rdf_valid), .rdf_rd_en(rdf_rd_en), .rdf_dout(rdf_dout),
    .af_full(af_full), .af_wr_en(af_wr_en), .af_addr_din(af_addr_din),
    .video_ready(video_ready), .video_valid(video_valid), .video(video),
    .frame_interrupt(frame_interrupt)
);


initial begin
    Reset = 1;
    rdf_valid = 0; af_full = 1; video_ready = 0;
    rdf_dout = {32'd0, 32'd0, 32'd0, 32'd0};

    repeat (5) @(posedge cpu_clk_g);
    Reset = 0;
    @(negedge cpu_clk_g);
    rdf_valid = 1; af_full = 0; video_ready = 1;

    //Runs until framecount is sufficient (see below)
end


integer frame_count = 0;
wire [30:14] trigWatch = af_addr_din[30:14];
reg [30:14] trigVal = 0;

always @(posedge cpu_clk_g) begin
    if (trigWatch !== trigVal) begin //Frame w/Leading-zeros & upper 5-bits of Y
        $display("INT:%b F#%0d ADDR:%h  F:%0d Y:%0d X:%0d",
                    frame_interrupt, frame_count, af_addr_din,
                    af_addr_din[20:19], //Frame (2-bits)
                    af_addr_din[18:09], //Y (10-bits)
                    {af_addr_din[08:00], 1'b0} //X (9-bits & a zero)
                );
        trigVal <= trigWatch;
    end
    if (frame_interrupt) begin
        frame_count <= frame_count + 1;
        $display("\n*** Frame#%0d ***", frame_count);
        if (frame_count > 2) $finish();
    end
end

endmodule
