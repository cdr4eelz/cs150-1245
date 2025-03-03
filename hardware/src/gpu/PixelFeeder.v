/* This module keeps a FIFO filled that then outputs to the DVI module. */

`include "gpcommands.vh"

module PixelFeeder #(
    parameter DVI_CLOCK_HZ=50_000_000,
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1, //TODO:Unimplemented!
    parameter PIXFO_CAPACITY=(2048/2), //max pixel_fifo "chunk" capacity (adjust to 256-bit units)
    parameter PIXFO_STARTUP =PIXFO_CAPACITY - 100, //fake source until pixel_fifo is this full
    parameter PIXFO_TARGET  =PIXFO_CAPACITY - 5, //1 "af" req => 2 "rdf" 128b resp => 8 pixfo 32b "rd"
    parameter COLT45_TESTPAT=0 // 1..3 are non-DDR test feeds of various sorts
)(
//System:
    input           cpu_clk_g,
    input           cpu_rst_g,
    input           dvi_clk_g,
    input           dvi_rst_g,
//DDR FIFOs (read-only) @cpu_clk_g:
    input           raf_full,
    output          raf_wren,
    output [ 27:0]  raf_addr,
    output          rdf_rden,
    input           rdf_wren,
    input  [127:0]  rdf_data,
// DVI driver @dvi_clk_g:
    input           video_ready,
    output          video_valid,
    output [ 31:0]  video, //[23:0]
// FRAME control <=> CPU @cpu_clk_g:
    input           pf_vframe,  //Signal new pf_wframe is to be captured this clock cycle
    input  [ 31:0]  pf_wframe,  //Address or Frame# for base of NEXT frame once this one is done
    output [ 15:0]  pf_status, //Composite status ("ready" signal not present/used)
    output          irq_frame     //1-cycle pulse after frame transition (except startup frame)
);

    // Hint: States
    localparam IDLE = 1'b0;
    localparam FETCH = 1'b1;

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE" *)
    reg  cpu_rst_r, dvi_rst_r; //Release synchronously to our clock
    always @(posedge cpu_clk_g) begin
        cpu_rst_r <= cpu_rst_g; //Internal reset, <rst>_r, unless really must sync-up release!
    end
    always @(posedge dvi_clk_g) begin
        dvi_rst_r <= dvi_rst_g; //Internal reset, <rst>_r, unless really must sync-up release!
    end


//***CLOCK CROSSING STRATEGY***
    // 1-request to wf => 2-responses on rdf => 8-pixels out of fifo (all 256-bits).
    //    Don't care about individual pixels in PixelFeeder!
    // pixel_fifo is 128-bit write (2K depth) and 32-bit read (8K depth).
    //    Forced to grab rdf output or lose it, no back-pressure opportunity there.
    // pixel_fifo available space tracked on CPU-clocked side in large chunks.  The chunks
    //    serve to reduce inter-clock signal rate, framebitskeep counters small (but separate),
    //    and create a hysteresis.  Synchronizing with 4-cycle signal/acknowledge loop.
    //NOTE: Cross-clock async registers might need ASYNC_REG=TRUE and/or TIG

// Cross-clock signal & acknowledge (using 4-cycle ack technique from Fall-13 for chunks)
    reg chunk_inc, chunk_ack, fifo_start;
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg chunk_inc_clkCPU, chunk_ack_clkDVI, fifo_start_clkDVI;

    always @(posedge dvi_clk_g) begin //Synchronize to DVI-clock
        {chunk_ack_clkDVI, fifo_start_clkDVI} <= {chunk_ack, fifo_start};
    end

    always @(posedge cpu_clk_g) begin //Synchronize to CPU-clock
        chunk_inc_clkCPU <= chunk_inc;
    end


// DVI-Clocked region (dvi_clk_g)

    reg  isRunning, wasRunning, feeder_valid;
    reg  [31:0] curCOL, curROW, curFRAME;
    reg  [ 3:0] count_dviread; //Rolls over on every 16 pixel "read-chunk"

    wire video_adv = (video_valid && video_ready); //reset will trump this
    wire rollCOL = (curCOL >= SCREEN_WIDTH-1); //Could use fast-counter/pixelrange
    wire rollROW = (curROW >= SCREEN_HEIGHT-1);

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) begin //Use synchronized reset
            {curCOL, curROW, curFRAME} <= 0;
            {feeder_valid, isRunning, wasRunning, count_dviread, chunk_inc} <= 0;
        end else begin
            feeder_valid <= 1'b1;
            wasRunning <= isRunning;
            if (video_adv) begin //They got a pixel, move on!
                if (isRunning) begin //If running, inform other clock-realm of chunks
                    if (&count_dviread) chunk_inc <= 1'b1; //Set on rollover
                    else if (chunk_ack_clkDVI) chunk_inc <= 1'b0;
                    count_dviread <= count_dviread + 1;
                end
                case ({rollROW, rollCOL}) //Manage our col/row/frame/scene business
                    (2'b11): begin
                        curFRAME <= curFRAME+1;
                        {curCOL,curROW} <= {32'd0, 32'd0};
                        if (fifo_start_clkDVI) isRunning <= 1'b1; //Switch to FIFO on frame boundary
                    end
                    (2'b01): {curCOL,curROW} <= {32'd0, curROW+1};
                    //2'b10 just means we're ON last row but not yet at end
                    default: curCOL <= curCOL+1;
                endcase
            end
        end
    end


    // FIFO to buffer the reads with a write width of 128 and read width of 32. We try to fetch blocks
    // until the FIFO is full.
    wire [ 31:0] feeder_raw, feeder_dout;
    wire [127:0] feeder_data;
    wire         feeder_wren, feeder_full, feeder_empty;
    wire [ 31:0] ignore_pixel = {curFRAME[14:0],1'b0, curROW[9:2], curCOL[9:2]};

    assign feeder_dout = feeder_raw; //(isRunning) ? feeder_raw : ignore_pixel;
    assign rdf_rden    = 1'b1; //Always ready to read (want to fill up)!

//TODO:Insert DDRStage before pixel_fifo to allow LITTLEWORDIAN flip

    pixel_fifo pf_fifo (
        .rst(cpu_rst_g), //Internal cross-clock sync
        //WRITE: CPU clock domain
        .wr_clk(cpu_clk_g),     // input
        .full(feeder_full),     // output
        .wr_en(feeder_wren),    //input              rdf_wren
        .din(feeder_data),      // input wire [127:0]  rdf_data
        //READ: DVI clock domain
        .rd_clk(dvi_clk_g),     // input
        .empty(feeder_empty),   // output
        .rd_en(video_ready && isRunning), // input
        .dout(feeder_raw),      // output  NOTE: First-word-fallthrough but no "valid" signal avail!
        // NEW UNKNOWN SIGNALS
        .wr_rst_busy( /*wr_rst_busy*/ ),    // output wire wr_rst_busy
        .rd_rst_busy( /*rd_rst_busy*/ )     // output wire rd_rst_busy
    );


//FAULT and ACTVE detection
    reg  video_fault_dvi, video_fault_cpu, video_fault, video_active;

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  video_active_clkCPU, video_fault_clkCPU;

    (* EQUIVALENT_REGISTER_REMOVAL="OFF" *)
    reg  [7:0] video_active_dvi, video_active_cpu;

    always @(posedge dvi_clk_g) begin
        if (dvi_rst_g) video_fault_dvi <= 1'b0;
        else if (video_ready && isRunning && feeder_empty) video_fault_dvi <= 1'b1;

        video_active_dvi[7:0] <= {video_active_dvi[6:0], (video_ready && video_valid)};
    end

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_g) video_fault_cpu <= 1'b0;
        else if (feeder_wren && feeder_full) video_fault_cpu <= 1'b1;

        video_active_clkCPU   <= |video_active_dvi;
        video_active_cpu[7:0] <= {video_active_cpu[6:0], video_active_clkCPU};
        video_active          <= |video_active_cpu || video_active_clkCPU;
        video_fault_clkCPU    <= video_fault_dvi;
        video_fault           <= video_fault_cpu || video_fault_clkCPU;
    end


generate if (COLT45_TESTPAT == 0) begin:PIXFO_DDREAD
// *** Normal PixelFeeder activity (DDR -> FIFO) ***

    assign feeder_wren = rdf_wren, feeder_data = rdf_data; //DDR-read to PIX-write
    assign video_valid = feeder_valid, video = feeder_dout[31:0]; //[23:0]


// CPU-Clocked region (cpu_clk_g)

    reg [64:0] pixel_count;
    reg [12:0] pend, pend_next; //pending mig_af requests (represent 256-bits each)
    reg [ 9:0] head_y, head_x;
    reg fr, fr_r, interrupt_r, state;
    reg [ 5:0] framebits, framebits_r, frame_next=0; // 0=test-pattern, 1=0x1040_0000, 2=0x1080_0000, etc.

    wire [31:0] head_addr = {4'h1, framebits, head_y[9:0], head_x[9:0], 2'b00}; //"Byte" address
    wire last_x = (head_x >= (((800/8)-1) * 8));
    wire last_y = (head_y >= (600-1));
    //1 chunk is 16 separate 32-bit fifo reads (4 mig_rdf responses, initiated by 2 mig_af requests)
    wire chunk_edge = chunk_inc_clkCPU && !chunk_ack; //Both are regs under our control
    wire raf_advance = raf_wren && !raf_full; //NOTE: Always raf_full until we assert raf_wren first!

    assign raf_addr  = {3'b000, head_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign raf_wren  = (state == FETCH); //Declare when FETCH addr ready (but might not happen)
    assign irq_frame = interrupt_r;
    assign pf_status = {
        video_fault, !video_active,
            framebits_r[5:0], //1-cycle latency avoids overly tight interconnect
        8'b0000_0000 //Maybe for overlay stuff later
    };

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            {frame_next, framebits_r, interrupt_r} <= 0;
        end else begin
            framebits_r <= framebits;
            interrupt_r <= (fr != fr_r); //Fires 1-cycle after REQ queued (not RESP or PIX)
            if (pf_vframe) frame_next <= `FRAME_BITS(pf_wframe); //Either addr style
        end
    end

    always @(*) begin
        case ( {chunk_edge, raf_advance} ) //chunk reduces by 2, fetch increases by 1
            2'b11: pend_next = pend - 1; //-2 +1
            2'b10: pend_next = pend - 2; //-2
            2'b01: pend_next = pend + 1; //   +1
            default: pend_next = pend;
        endcase
    end

    //Ensures 1+ IDLEs between FETCHs; also note (state==IDLE) ensures !raf_advance
    wire next_state = ((pend < PIXFO_TARGET) && !raf_advance) ? FETCH : IDLE;
//  wire next_state = ((pend < PIXFO_TARGET) && (state == IDLE)) ? FETCH : IDLE;

    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin //Standard reset for other stuff
            {chunk_ack, pend, fifo_start} <= 0;
            state <= IDLE;
            {fr, fr_r, head_y, head_x, pixel_count} <= 0;
            framebits <= frame_next;
        end else begin
            pend <= pend_next;
            state <= next_state;
            fr_r <= fr;
            chunk_ack <= chunk_inc_clkCPU;

            if (pend_next > PIXFO_STARTUP) begin
                fifo_start <= 1'b1;
            end

            if (raf_advance) begin //Advance x/y/frame (right AFTER end of this cycle)
                pixel_count <= pixel_count + 8;
                if (last_y && last_x) begin
                    fr <= ~fr; head_y <= 0; head_x <= 0;
                    framebits <= frame_next;
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
    if (raf_advance && ((head_x == 0) || (last_x && last_y))) begin
        if (last_x && last_y) $display("LAST:");
        $display("  aB:%08h aD:%08h  F:%b X:%04d Y:%04d  PEND:%04d PIX:%0d",
                 head_addr, raf_addr,
                 fr, head_x, head_y,
                 pend, pixel_count);
    end
end
// synthesis translate_on


end else if (COLT45_TESTPAT == 1) begin:PIXFO_SWEEP
// *** Simple test pattern output through the FIFO ***

    assign video_valid = feeder_valid, video = feeder_dout[23:0];
    assign raf_wren = 1'b0;

    reg [15:0] sweep_RGB;
    reg [63:0] sweep_cnt;
    always @(posedge cpu_clk_g) begin
        if (cpu_rst_r) begin
            sweep_RGB <= 16'hE2A2;
            sweep_cnt <= 0;
        end else if (feeder_wren) begin
            sweep_RGB <= sweep_RGB+5;
            sweep_cnt <= sweep_cnt+1; //Sent another 4 pixels
        end
    end

    assign feeder_wren = !feeder_full;
    assign feeder_data = {
        8'd0, 24'h808080, // Grey stripe
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0],
        8'd0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]
    };


end else if (COLT45_TESTPAT == 2) begin:DIRECT_SWEEP
// *** DIRECTLY send a pretty and scrolling pattern ***
    reg [15:0] sweep_RGB;
    assign video = {8'b0, sweep_RGB[15:8], sweep_RGB[11:4], sweep_RGB[7:0]};
    assign video_valid = 1'b1;
    always @(posedge dvi_clk_g) begin
        if (dvi_rst_r) sweep_RGB <= 16'hE2A2;
        else if (video_valid && video_ready) sweep_RGB <= sweep_RGB+5;
    end


end else if (COLT45_TESTPAT == 3) begin:DIRECT_PAT
// *** DIRECTLY inject simple pattern gen from FALL-2013-CP1 ***
    PatternGenerator #(
        .CLOCK_HZ(DVI_CLOCK_HZ), //DVI Clock
        .SCREEN_WIDTH(800), .SCREEN_HEIGHT(600),
        .SCENES_PER_SEC(1)
    ) patgen (
        .clock(dvi_clk_g), .reset(dvi_rst_r),
        .video(video), .video_valid(video_valid),
        .video_ready(video_ready)
    );
end endgenerate

endmodule

/* Interesting BUG along the way when driving "af_wren" improperly here!!!
    The RequestController doesn't give valid "full" signal unless we TRY to write an address...
    ...so cannot adjust our raf_wren based upon the raf_full signal (like with direct FIFO access).

WARNING:Xst:2170 - Unit ml505top : the following signal(s) form a combinatorial loop: mem_arch/pixel_raf_wren, mem_arch/req_con/fifo_access<5>.
*/
