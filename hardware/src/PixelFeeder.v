/* This module keeps a FIFO filled that then outputs to the DVI module. */
//TODO: Make test patterns selectable via software (and keypress)

module PixelFeeder #(
    parameter COLT45_TESTPAT=1
) (                 //System:
                    input          cpu_clk_g,
                    input          clk50_g, // DVI Clock
                    input          rst,
                    //DDR2 FIFOS:
                    input          rdf_valid,
                    input          af_full,
                    input  [127:0] rdf_dout,
                    output         rdf_rd_en,
                    output         af_wr_en,
                    output [30:0]  af_addr_din,
                    // DVI module:
                    output [23:0]  video,
                    output         video_valid,
                    input          video_ready,

		    output frame_interrupt);

    wire feeder_den, feeder_empty, feeder_full;
    wire [127:0] feeder_din;

    // Hint: States
    localparam IDLE = 1'b0;
    localparam FETCH = 1'b1;

    localparam PIXFO_CAPACITY = 256; //Max # 128-bit writes to fill
    localparam PIXFO_TARGET = PIXFO_CAPACITY - 2; //Each read request yields 2
    localparam FRAME0_SEL = 2'b01, FRAME1_SEL = 2'b10;

    /**************************************************************************
    * YOUR CODE HERE: Write logic to keep the FIFO as full as possible.
    **************************************************************************/
generate if (COLT45_TESTPAT == 0) begin:PIXFO_DDREAD
    assign feeder_den = rdf_valid, feeder_din = rdf_dout; //DDR-read to PIX-write

    //Traverse row & col, flip source frame & fire interrupt (pulse) between.
    //Once arbiter gives attention, a read will ensure (two chunks). (mimic "Cache.v")

    //localparam FRAME0_BASE = 32'h1040_0000, FRAME1_BASE = 32'h1080_0000;
    //address = {8'h10, 2'b01, y, x, 2’b0}  _01 are high 2-bits of "4" in base0
    //address = {8'h10, 2'b10, y, x, 2’b0}  _10 are high 2-bits of "8" in base1
    //Each pixel 32-bits (though top byte is zero)
    //X sequential (would allow fetching 4 at a time

    wire [30:0] next_addr;
    wire [9:0] head_y = 10'd0, head_x = 10'd0;
    assign next_addr = {7'b000_0000, FRAME0_SEL, head_y, head_x, 2'b00};

end else if (COLT45_TESTPAT == 1) begin:PIXFO_SWEEP
    reg [15:0] sweep_RGB;
    always @(posedge cpu_clk_g) begin
        if (rst) sweep_RGB <= 16'hE2A2;
        else if (feeder_den) sweep_RGB <= sweep_RGB+5;
    end
    assign feeder_den = !feeder_full, feeder_din = {
        8'd0, 24'h808080, // Grey stripe
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]
    };
end endgenerate


generate if (COLT45_TESTPAT <= 1) begin:PIXEL_FIFO
    /* We drop the first frame to allow the buffer to fill with data from
    * DDR2. This gives alignment of the frame. */
    reg  [31:0] ignore_count;

    always @(posedge clk50_g) begin //NOTE: Was cpu_clk_g in skeleton
       if(rst)
            ignore_count <= 32'd480000; // 600*800 
       else if(ignore_count != 0 & video_ready)
            ignore_count <= ignore_count - 32'b1;
       else
            ignore_count <= ignore_count;
    end

    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is full.
    wire [31:0] feeder_dout;

    pixel_fifo feeder_fifo(
    	.rst(rst),
    	.wr_clk(cpu_clk_g),
    	.rd_clk(clk50_g),
    	.din(feeder_din), //rdf_dout
    	.wr_en(feeder_den), //rdf_valid
    	.rd_en(video_ready & ignore_count == 0),
    	.dout(feeder_dout),
    	.full(feeder_full),
    	.empty(feeder_empty));

    assign video = feeder_dout[23:0];
    assign video_valid = 1'b1;

end else if (COLT45_TESTPAT == 2) begin:DIRECT_SWEEP
    // DIRECTLY send a pretty changing pattern
    reg [15:0] sweep_RGB;
    assign video = {sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]};
    assign video_valid = 1'b1;
    always @(posedge clk50_g) begin
        if (rst) sweep_RGB <= 16'hE2A2;
        else if (video_valid && video_ready) sweep_RGB <= sweep_RGB+5;
    end

end else begin:DIRECT_PAT
    // DIRECTLY inject simple pattern gen from FALL-2013-CP1
    PatternGenerator #(
        .CLOCK_HZ(50_000_000), //DVI Clock
        .SCREEN_WIDTH(800), .SCREEN_HEIGHT(600),
        .SCENES_PER_SEC(1)
    ) patgen (
        .clock(clk50_g), .reset(rst),
        .video(video), .video_valid(video_valid),
        .video_ready(video_ready)
    );
end endgenerate

endmodule
