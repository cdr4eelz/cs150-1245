/* This module keeps a FIFO filled that then outputs to the DVI module. */

module PixelFeeder #(
    parameter COLT45_TESTPAT = 2
)                   ( //System:
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

localparam FRAME0_BASE = 32'h1040_0000, FRAME1_BASE = 32'h1080_0000;
//address = {8'h10, 2'b01, y, x, 2’b0}  _01 are high 2-bits of "4" in base0
//address = {8'h10, 2'b10, y, x, 2’b0}  _10 are high 2-bits of "8" in base1
//Each pixel 32-bits (though top byte is zero)
//X sequential (would allow fetching 4 at a time
localparam FRAME0_SEL = 2'b01, FRAME1_SEL = 2'b10;
wire [30:0] next_addr;
wire [9:0] head_y = 10'd0, head_x = 10'd0;
assign next_addr = {7'b000_0000, FRAME0_SEL, head_y, head_x, 2'b00};

//Traverse row & col, flip source frame & fire interrupt (pulse) between.
//Request goes out af, and back later on rdf...Might help to think of single offset
//  into series of pixels or advance a HEAD & TAIL somewhat separately.
//  TAIL goes to pixel-fifo (splits pair of reads into 8 pixels).
//  HEAD jumps 4 pixels & triggers frame interrupt.
//No need for HEAD/TAIL...memory FIFOs are not for queueing, just clock traversal.
//Once arbiter gives attention, a read will ensure (two chunks). (mimic "Cache.v")
//Place chunks in register-stages to be pieced out to pixel-fifo.

    // Hint: States
    localparam IDLE = 1'b0;
    localparam FETCH = 1'b1;

    reg  [31:0] ignore_count;
    wire feeder_empty, feeder_full;

    /**************************************************************************
    * YOUR CODE HERE: Write logic to keep the FIFO as full as possible.
    **************************************************************************/
//Luckily byte-enables are always 4x4x4 from memory? (800 /4 /2 -> 100 af addr)
//Data comes in two "halves"???  (Two fetches from read FIFO)
//How to consider FIFO capacity?

//Skeleton signals go straight from memory FIFO to pixel FIFO so maybe one pixel
//  at a time???  Or go wider & register in between to do chunks of 4.

//af_full = !ready : Keep requesting
//af_wr_en: !af_full && !wdf_full && "running" (always after init)
//af_addr_din: HEAD address of next 4-pixel (32x4x4) chunk.

//rdf_valid (straight from MEM->PIX FIFOS)
//rdf_dout[127:0] 4-pixels worth? or just low 32-bits?
//rdf_rd_en: Read when we know next FIFO can take 4x32
//frame_interrupt: on end of frame (on last address request?)

    /* We drop the first frame to allow the buffer to fill with data from
    * DDR2. This gives alignment of the frame. */
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
    	.din(rdf_dout),
    	.wr_en(rdf_valid),
    	.rd_en(video_ready & ignore_count == 0),
    	.dout(feeder_dout),
    	.full(feeder_full),
    	.empty(feeder_empty));

generate
if (COLT45_TESTPAT == 0) begin:PAT_FEED
    assign video = feeder_dout[23:0];
    assign video_valid = 1'b1;
end else if (COLT45_TESTPAT == 1) begin:PAT_GEN
    // DIRECTLY inject simple pattern gen from other semester
    PatternGenerator #(
        .CLOCK_HZ(50_000_000), //DVI Clock
        .SCREEN_WIDTH(800), .SCREEN_HEIGHT(600), .SCENES_PER_SEC(1)
    ) (
        .clock(clk50_g), .reset(rst),
        .video(video), .video_valid(video_valid), .video_ready(video_ready)
    );
end else begin:PAT_SWEEP
    reg [15:0] sweep_RGB;
    always @(posedge clk50_g) begin
        if (rst) begin
            sweep_RGB <= 16'hE2A2;
        end else begin
            if (video_valid && video_ready) begin
                sweep_RGB <= (sweep_RGB[15]) ? ~sweep_RGB : sweep_RGB+5;
            end
        end
    end
    assign video = {sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]};
    assign video_valid = 1'b1;
end
endgenerate

endmodule
