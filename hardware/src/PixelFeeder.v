/* This module keeps a FIFO filled that then outputs to the DVI module. */

module PixelFeeder #(
    parameter CLOCK_HZ = 50_000_000,
    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600,
//    parameter SCREEN_WIDTH = 640, SCREEN_HEIGHT = 480,
    parameter COLT45_TESTPAT=0
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

    localparam PIXFO_CAPACITY = (2048/2); //pixel_fifo max capacity (adjusted for 256-bit units)
    localparam PIXFO_TARGET = PIXFO_CAPACITY - 5; //1 af req => 2 x 128-bit rdf => 8 x 32-bit pixfo rd

//***CLOCK CROSSING STRATEGY***
    // 1-request to wf => 2-responses on rdf => 8-pixels out of fifo (all 256-bits).
    //    Don't care about individual pixels in PixelFeeder!
    // pixel_fifo is 128-bit write (2K depth) and 32-bit read (8K depth).
    //    Forced to grab rdf output or lose it, no back-pressure opportunity there.
    // pixel_fifo available space tracked on CPU-clocked side in large chunks.  The chunks
    //    serve to reduce inter-clock signal rate, keep counters small (but separate),
    //    and create a hysteresis.  Synchronizing with 4-cycle signal/acknowledge loop.

// Cross-clock signal & acknowledge (using 4-cycle ack technique from Fall-13)
    reg  chunk_inc; //From DVI-clock realm
    reg  chunk_ack; //From CPU-clock realm
    //NOTE: Cross-clock async registers might need ASYNC_REG=TRUE

// DVI-Clocked region (clk50_g)

    reg  rst_clk50, chunk_ack_clk50;
    always @(posedge clk50_g) begin
        rst_clk50 <= rst; //Synchronize to DVI-clock (more for "release" than onset)
        chunk_ack_clk50 <= chunk_ack; //Synchronize to DVI-clock
    end

    reg  [31:0] curCOL, curROW, curFRAME;
    wire advanceRVA = video_valid && video_ready; //reset will trump this
    wire rollCOL = (curCOL >= SCREEN_WIDTH-1); //Could use fast-counter/pixelrange
    wire rollROW = (curROW >= SCREEN_HEIGHT-1);
    always @(posedge clk50_g) begin
        if (rst_clk50) begin //Use synchronized reset
            {curCOL, curROW, curFRAME} <= 0;
        end else begin
            if (advanceRVA) begin //They got a pixel, move on!
                case ({rollROW, rollCOL}) //Manage our col/row/frame/scene business
                    (2'b11): begin
                        curFRAME <= curFRAME+1;
                        {curCOL,curROW} <= {32'd0, 32'd0};
                    end
                    (2'b01): {curCOL,curROW} <= {32'd0, curROW+1};
                    //2'b10 just means we're ON last row but not yet at end
                    default: curCOL <= curCOL+1;
                endcase
            end
        end
    end

    reg  [ 3:0] count_dviread; //Rolls over on every 16 pixel "read-chunk"
    reg  isRunning;
    wire feeder_valid = !rst_clk50;
    always @(posedge clk50_g) begin
        if (rst_clk50) begin //Use synchronized reset
            {isRunning, count_dviread, chunk_inc} <= 0;
        end if (video_ready) begin
            if (isRunning) begin
                if (&count_dviread) chunk_inc <= 1'b1; //Set on rollover
                else if (chunk_ack_clk50) chunk_inc <= 1'b0;
                count_dviread <= count_dviread + 1;
            end
        end
    end


    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is full.
    wire [31:0] feeder_raw, feeder_dout;
    wire feeder_den, feeder_full, feeder_empty;
    wire [127:0] feeder_din;

    pixel_fifo feeder_fifo(
        .rst(rst), //Reset is usually synchronized internally (when only 1 reset is present)
        .wr_clk(cpu_clk_g),
        .wr_en(feeder_den), //rdf_valid
        .din(feeder_din), //rdf_dout
        .full(feeder_full),
        .rd_clk(clk50_g),
        .rd_en(video_ready && isRunning),
        .dout(feeder_raw),
        .empty(feeder_empty));

    assign feeder_dout = (isRunning) ? feeder_raw : {7'hFF,curFRAME[7:0],curROW[7:0],curCOL[7:0]};
    assign rdf_rd_en = 1'b1; //Really a "ready" signal, not standard FIFO "enable"

generate if (COLT45_TESTPAT == 0) begin:PIXFO_DDREAD
// *** Normal PixelFeeder activity (DDR -> FIFO) ***

    assign feeder_den = rdf_valid, feeder_din = rdf_dout; //DDR-read to PIX-write
    assign video_valid = feeder_valid, video = feeder_dout[23:0];

// CPU-Clocked region (cpu_clk_g)

    reg [64:0] pixel_count;
    reg chunk_inc_clkCPU; //chunk is 16 x 32-bit fifo reads (from 2 mig_af requests)
    reg [12:0] pend, pend_next; //pending mig_af requests (represent 256-bits each)
    reg [9:0] head_y, head_x;
    reg state;
    reg fr, fr_r; // 0/1 turns into _01/_10 below (0x1040_0000 or 0x1080_0000 frame base)

    wire chunk_edge = chunk_inc_clkCPU && !chunk_ack; //Both are regs under our control
    wire last_x = (head_x >= (((800/8)-1) * 8));
    wire last_y = (head_y >= (600-1));
    wire [31:0] head_addr = {8'h10, 2'b01/*fr,~fr*/, head_y[9:0], head_x[9:0], 2'b00}; //"Byte" address
    wire next_state = (pend < PIXFO_TARGET) ? FETCH : IDLE; //Try to FETCH until semi-saturate the FIFO
    wire af_advance = af_wr_en && !af_full;

    assign af_addr_din = {6'd0, head_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign af_wr_en = (state == FETCH); //Declare that we want to write an address (but might not happen)
    assign frame_interrupt = (fr != fr_r); //Fires right after request gets queued (not resp or pix)

    always @(*) begin
        case ( {chunk_edge, af_advance} ) //chunk reduces by 2, fetch increases by 1
            2'b11: pend_next = pend - 1; //-2 +1
            2'b10: pend_next = pend - 2; //-2
            2'b01: pend_next = pend + 1; //   +1
            default: pend_next = pend;
        endcase
    end

    always @(posedge cpu_clk_g) begin
        if (rst) begin
            {chunk_inc_clkCPU, chunk_ack, pend} <= 0;
            state <= IDLE;
            {fr, fr_r, head_y, head_x, pixel_count} <= 0;
        end else begin
            chunk_inc_clkCPU <= chunk_inc;
            chunk_ack <= chunk_inc_clkCPU;
            pend <= pend_next;
            state <= next_state;
            fr_r <= fr;
            if (af_advance) begin //Advance x/y/frame (right AFTER end of this cycle)
                pixel_count <= pixel_count + 8;
                if (last_y && last_x) begin
                    fr <= ~fr; head_y <= 0; head_x <= 0;
                end else if (last_x) begin
                    head_y <= head_y + 1; head_x <= 0;
                end else begin
                    head_x <= head_x + 8;
                end
            end
        end
    end

// synthesis translate_off
always @(posedge cpu_clk_g) begin
    if (af_advance && ((head_x == 0) || (last_x && last_y))) begin
        if (last_x && last_y) $display("LAST:");
        $display("  aB:%08h aD:%08h  F:%b X:%04d Y:%04d  PEND:%04d PIX:%0d",
                 head_addr, af_addr_din,
                 fr, head_x, head_y,
                 pend, pixel_count);
    end
end
// synthesis translate_on


end else if (COLT45_TESTPAT == 1) begin:PIXFO_SWEEP
// *** Simple test pattern output through the FIFO ***

    assign video_valid = feeder_valid, video = feeder_dout[23:0];
    assign af_wr_en = 1'b0;

    reg [15:0] sweep_RGB;
    reg [63:0] sweep_cnt;
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


end else if (COLT45_TESTPAT == 2) begin:DIRECT_SWEEP
// *** DIRECTLY send a pretty and scrolling pattern ***
    reg [15:0] sweep_RGB;
    assign video = {sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]};
    assign video_valid = 1'b1;
    always @(posedge clk50_g) begin
        if (rst_clk50) sweep_RGB <= 16'hE2A2;
        else if (video_valid && video_ready) sweep_RGB <= sweep_RGB+5;
    end


end else if (COLT45_TESTPAT == 3) begin:DIRECT_PAT
// *** DIRECTLY inject simple pattern gen from FALL-2013-CP1 ***
    PatternGenerator #(
        .CLOCK_HZ(50_000_000), //DVI Clock
        .SCREEN_WIDTH(800), .SCREEN_HEIGHT(600),
        .SCENES_PER_SEC(1)
    ) patgen (
        .clock(clk50_g), .reset(rst_clk50),
        .video(video), .video_valid(video_valid),
        .video_ready(video_ready)
    );
end endgenerate

endmodule

/* Interesting BUG along the way when driving "af_wr_en" improperly here!!!
    The RequestController doesn't give valid "full" signal unless we TRY to write an address...
    ...so cannot adjust our af_wr_en based upon the af_full signal (like with direct FIFO access).

WARNING:Xst:2170 - Unit ml505top : the following signal(s) form a combinatorial loop: mem_arch/pixel_af_wr_en, mem_arch/req_con/fifo_access<5>.
*/