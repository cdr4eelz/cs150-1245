`timescale 1ns/1ns //Modest precision (maybe longer duration more convenient)

module PatternGenerator_tb;

    parameter CLK_PERIOD = 20; // 20 * 1ns timescale
    parameter CLK_HI = (CLK_PERIOD / 2.0); //Watchout for divisibility & precision
    parameter CLK_LO = CLK_PERIOD - (CLK_PERIOD / 2.0);
    parameter CLK_HZ = (1_000_000_000 / CLK_PERIOD);

    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600;

    reg reset;
    reg clock;
    integer cycle;
    initial begin
        clock = 0;
        cycle = 0;
    end
    always begin
        #CLK_LO clock = 1;
        #CLK_HI clock = 0;
        if (clock) cycle = cycle + 1;
    end

    wire [23:0] dvi_video;
    wire dvi_video_valid;
    reg dvi_video_ready = 1'bz;

    PatternGenerator #(
      .CLOCK_HZ(CLK_HZ),
      .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
      .SCENES_PER_SEC(20) //Quick rate to keep sim duration short
    ) dut (
      .clock(clock),
      .reset(reset),

      .video(dvi_video),
      .video_valid(dvi_video_valid),
      .video_ready(dvi_video_ready)
    );

initial begin
    #CLK_PERIOD;
    reset = 1'b1;
    dvi_video_ready = 1'b0;
    #(CLK_PERIOD*3);

//    $monitor("#%d-%b R:%b V:%b RGB:%h", cycle, reset,
//             dvi_video_ready, dvi_video_valid, dvi_video);

    while (clock) #1;
    reset = 1'b0;
    #(CLK_PERIOD*2); while (clock) #1;
    dvi_video_ready = 1'b1;

    #(CLK_PERIOD*10); while (clock) #1;
    dvi_video_ready = 1'b0;
    while (!clock) #1;
    while (clock) #1;
    dvi_video_ready = 1'b1;
end

always @(*) if (cycle >= (SCREEN_WIDTH*SCREEN_HEIGHT*300)) begin
    $display("Done: %d", cycle);
    $finish();
end

endmodule
