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

    // Hint: States
    localparam IDLE = 1'b0;
    localparam FETCH = 1'b1;

    localparam PIXFO_CAPACITY = 256; //Max # 128-bit writes to fill
    localparam PIXFO_TARGET = PIXFO_CAPACITY - 7; //1 af req => 2 x 128-bit rdf => 8 x 32-bit pixfo rd

    localparam FRAME0_SEL = 2'b01, FRAME1_SEL = 2'b10;
    //localparam FRAME0_BASE = 32'h1040_0000, FRAME1_BASE = 32'h1080_0000;
    //address = {8'h10, framesel, y, x, 2’b0}  _01 or _10 framesel are high bits of 4 or 8 in base.

    // 1-request => 2-responses => 8-pixels (all 256-bits).
    // Don't care about individual pixels in PixelFeeder!

    // pixel_fifo is 128-bit write (2K depth) and 32-bit read (8K depth).
    // Forced to grab rdf output or lose it, no back-pressure opportunity there.

    // Counting pixel_fifo available space CPU-clocked side in large chunks.  The chunks
    //    serve to reduce inter-clock signal rate, keep counters small (but separate),
    //    and create a hysteresis.  Synchronizing with acknowledge technique (4-cycle or
    //    whatever) though if glitches 

    //Traverse row & col, flip source frame & fire interrupt (pulse) between.
    //Once arbiter gives attention, a read will ensure (two chunks). (mimic "Cache.v")

// Cross-clock signal & acknowledge (using 4-cycle ack technique from Fall-13)
    reg  chunk_inc; //From DVI-clock realm
    reg  chunk_ack; //From CPU-clock realm
    //NOTE: Cross-clock async registers might need ASYNC_REG=TRUE

// DVI-Clocked region (clk50_g)

    /* We drop the first frame to allow the buffer to fill with data from
    * DDR2. This gives alignment of the frame. */
    reg  [31:0] ignore_count;
    reg  [ 3:0] count_dviread; //Rolls over for each 16 pixel "read-chunk"
    reg  rst_clk50, running_reg, chunk_ack_clk50;

    always @(posedge clk50_g) begin
        rst_clk50 <= rst; //Synchronize to DVI-clock
        if (rst_clk50) begin //Use synchronized reset
            ignore_count <= 32'd480000; // 600*800 
            {running_reg, chunk_ack_clk50, count_dviread, chunk_inc} <= 0;
        end else begin
            running_reg <= 1'b1;
            chunk_ack_clk50 <= chunk_ack; //Synchronize to DVI-clock
            if (video_ready && running_reg && (ignore_count != 0)) begin
                ignore_count <= ignore_count - 32'b1;
            end if (video_ready && running_reg) begin
                count_dviread <= count_dviread+1;
                if (&count_dviread) chunk_inc <= 1'b1; //Set on rollover
                else if (chunk_ack_clk50) chunk_inc <= 1'b0;
            end else if (chunk_ack_clk50) chunk_inc <= 1'b0;
        end
    end

    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is full.
    wire [31:0] feeder_dout;
    wire feeder_den, feeder_full, feeder_empty;
    wire [127:0] feeder_din;

    pixel_fifo feeder_fifo(
    	.rst(rst), //Depending on coregen settings, reset is synchronized internally
    	.wr_clk(cpu_clk_g),
    	.wr_en(feeder_den), //rdf_valid
    	.din(feeder_din), //rdf_dout
    	.full(feeder_full),
    	.rd_clk(clk50_g),
    	.rd_en(video_ready && running_reg && (ignore_count == 0)),
    	.dout(feeder_dout),
    	.empty(feeder_empty));


generate if (COLT45_TESTPAT == 0) begin:PIXFO_DDREAD
// *** Normal PixelFeeder activity (DDR -> FIFO) ***

// CPU-Clocked region (cpu_clk_g)

    wire [30:0] next_addr;
    wire [ 9:0] head_y = 10'd0, head_x = 10'd0;
    assign next_addr = {7'b000_0000, FRAME0_SEL, head_y, head_x, 2'b00};
    reg chunk_inc_clkCPU;

    always @(posedge cpu_clk_g) begin
        if (rst) begin
            chunk_inc_clkCPU <= 0;
            chunk_ack <= 0;
        end else begin
            chunk_inc_clkCPU <= chunk_inc;
            chunk_ack <= chunk_inc_clkCPU;
        end
    end

    assign feeder_den = rdf_valid, feeder_din = rdf_dout; //DDR-read to PIX-write
    assign video_valid = running_reg, video = feeder_dout[23:0];


end else if (COLT45_TESTPAT == 1) begin:PIXFO_SWEEP
// *** Simple test pattern output through the FIFO ***

    reg [15:0] sweep_RGB;
    reg [31:0] sweep_cnt;
    always @(posedge cpu_clk_g) begin
        if (rst) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (feeder_den) begin
            sweep_RGB <= sweep_RGB+5;
            sweep_cnt <= sweep_cnt+1; //Sent another 4 pixels
        end
    end

    assign feeder_den = !feeder_full;
    assign feeder_din = {
        8'd0, 24'h808080, // Grey stripe
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]
    };
    assign video_valid = running_reg, video = feeder_dout[23:0];


end else if (COLT45_TESTPAT == 2) begin:DIRECT_SWEEP
// *** DIRECTLY send a pretty and scrolling pattern ***
    reg [15:0] sweep_RGB;
    assign video = {sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]};
    assign video_valid = 1'b1;
    always @(posedge clk50_g) begin
        if (rst) sweep_RGB <= 16'hE2A2;
        else if (video_valid && video_ready) sweep_RGB <= sweep_RGB+5;
    end


end else if (COLT45_TESTPAT == 3) begin:DIRECT_PAT
// *** DIRECTLY inject simple pattern gen from FALL-2013-CP1 ***
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

/* RAMBLINGS:

    DDR "FIFOs" are simply muxed to shared FIFOs that we don't get to stall, without
    any individual buffering.  We are forced to grab (or lose) anything coming back
    on rdf_out, hence the direct tie of rdf_rd_en & pixel_fifo.wr_en to rdf_valid
    and futility of using pixel_fifo.full checking.  We face an increment of 256-bits
    for each 1 request on af_addr_din accepted...turning into 2 responses (128-bits each)
    eventually out of rdf_dout...turning into 8 reads (32-bits each) out of DVI clocked
    side of pixel_fifo.  We have advantage of 1-to-8 ratio DDR requests to DVI reads at
    either identical or comparable clock rates.  One obvious trick is to rebuild the
    pixel_fifo to include either counter or range assertion support...but I guess we are
    meant to confront issue ourselves to grasp it best.  I'm using a simple signal/ack
    whereby the DVI side informs the CPU-clocked side of chunks of read data...allowing
    a coarse-grain count to be kept at the request initiating spot.
*/
