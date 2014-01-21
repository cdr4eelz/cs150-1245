`timescale 1ns/1ns //NOTE: Very modest precision!

`include "cpuglobal.vh"

module PixelFeederTestbench;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;
    
    wire fifo_reset_async, fifo_reset_sync, cpu_rst;
    wire user_clk_g, cpu_clk_g, clk200_g, clk50_g;


reg  rdf_valid, af_full, video_ready;
reg  [127:0] rdf_dout;
wire rdf_rd_en, af_wr_en, video_valid, frame_interrupt;
wire [30:0]  af_addr_din;
wire [23:0]  video;

PixelFeeder #(
    .COLT45_TESTPAT(0)
) DUT (
    .cpu_clk_g(cpu_clk_g), .clk50_g(clk50_g), .rst(cpu_rst),
    .rdf_valid(rdf_valid), .rdf_rd_en(rdf_rd_en), .rdf_dout(rdf_dout),
    .af_full(af_full), .af_wr_en(af_wr_en), .af_addr_din(af_addr_din),
    .video_ready(video_ready), .video_valid(video_valid), .video(video),
    .frame_interrupt(frame_interrupt)
);


    reg Clock, Reset, init_done;
    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;
    
    assign cpu_rst = Reset || ~init_done;
    // Reset shift register:
    reg [2:0] rst_sr;
    assign fifo_reset_sync = |rst_sr;
    assign fifo_reset_async = Reset | (|rst_sr);
    always @(posedge cpu_clk_g) begin
        rst_sr <= {rst_sr[1:0], Reset};
    end


    wire pll_fb, pll_lock, cpu_clk, clk200, clk0, clk90, clkdiv0, clk50;
    PLL_BASE
    #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(32),
        .CLKFBOUT_PHASE(0.0),
        .CLKIN_PERIOD(10.0),

        .CLKOUT0_DIVIDE(16),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),

        .CLKOUT1_DIVIDE(4),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(0.0),

        .CLKOUT2_DIVIDE(4),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT2_PHASE(0.0),

        .CLKOUT3_DIVIDE(4),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT3_PHASE(90.0),

        .CLKOUT4_DIVIDE(8),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT4_PHASE(0.0),

        .CLKOUT5_DIVIDE(16),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT5_PHASE(0.0),

        .COMPENSATION("SYSTEM_SYNCHRONOUS"),
        .DIVCLK_DIVIDE(4),
        .REF_JITTER(0.100)
    )
    user_clk_pll
    (
        .CLKFBOUT(pll_fb),
        .CLKOUT0(cpu_clk),
        .CLKOUT1(clk200),
        .CLKOUT2(clk0),
        .CLKOUT3(clk90),
        .CLKOUT4(clkdiv0),
        .CLKOUT5(clk50),
        .LOCKED(pll_lock),
        .CLKFBIN(pll_fb),
        .CLKIN(user_clk_g),
        .RST(1'b0)
    );
    IBUFG user_clk_buf ( .I(Clock),    .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
    BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
    BUFG  clkdiv50_buf ( .I(clk50),    .O(clk50_g)    );


initial begin
    Reset = 1;
    rdf_valid = 0; af_full = 1; video_ready = 0;
    rdf_dout = {32'd0, 32'd0, 32'd0, 32'd0};

    repeat (5) @( posedge cpu_clk_g );
    Reset = 0; init_done = 1;
    rdf_valid = 1; af_full = 0; video_ready = 1;

    $monitor("ADDR: %h  INT:%b", af_addr_din, frame_interrupt);

end

endmodule
