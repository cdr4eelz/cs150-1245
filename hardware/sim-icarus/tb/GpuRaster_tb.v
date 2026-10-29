// GpuRaster_tb: FrameFiller + LineEngine -> ScanLineRunner (2 SLR clients) -> DDR write FIFOs,
// checked against a reference framebuffer.
//
// The FIFO side is a model with random back-pressure (one full flag for both FIFOs, as
// base_mem/RequestController.v provides) that applies each
// write (one caf address + two 128-bit wdf beats with active-low byte masks) to a
// 1024x1024-pixel frame, using the same word order as base_mem/Cache.v for the given
// LITTLEWORDIAN (LW=1: beat 1 = pixels 0..3 of the 8-pixel chunk, pixel 0 in bits 127:96;
// LW=0: beat 1 = pixels 7..4, pixel 7 in bits 127:96). The reference is drawn by the
// testbench: a fill writes the edge color at columns 0 and W-1 and 0xFF000000|color between;
// a line is the C model in LineEngine.v's comment (swline), one pixel per step in its color.
// Every pixel of the frame (including outside the 800x600 screen) is compared at the end;
// writes to any other frame are errors. Prints PASS / FAIL.
`timescale 1ns/1ps
module GpuRaster_tb;
`ifndef LW
  `define LW 1
`endif
`ifndef NLINES
  `define NLINES 60
`endif
    localparam W = 800, H = 600, LW = `LW;
    localparam [5:0] FRAME = 6'h05;          // frame base 0x1140_0000
    localparam [31:0] FRAME_ADDR = {4'h1, FRAME, 22'b0};
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    // engines
    wire        FF_ready, LE_ready;
    reg         FF_valid = 0;
    reg  [31:0] FF_color = 0, FF_frame = 0;
    reg         LE_color_valid = 0, LE_x0_valid = 0, LE_y0_valid = 0, LE_x1_valid = 0, LE_y1_valid = 0, LE_trigger = 0;
    reg  [31:0] LE_color = 0, LE_frame = 0;
    reg  [ 9:0] LE_point = 0;
    wire [ 1:0] SLRs_ready, SLRs_valid;
    wire [63:0] SLRs_frame, SLRs_color_edge, SLRs_color_fill;
    wire [19:0] SLRs_row, SLRs_col_start, SLRs_col_finish;

    FrameFiller #(.SCREEN_WIDTH(W), .SCREEN_HEIGHT(H)) ff (
        .clk(clk), .rst(rst), .FF_ready(FF_ready), .FF_valid(FF_valid), .FF_color(FF_color), .FF_frame(FF_frame),
        .SLR_ready(SLRs_ready[0]), .SLR_valid(SLRs_valid[0]), .SLR_frame(SLRs_frame[31:0]),
        .SLR_color_edge(SLRs_color_edge[31:0]), .SLR_color_fill(SLRs_color_fill[31:0]),
        .SLR_row(SLRs_row[9:0]), .SLR_col_start(SLRs_col_start[9:0]), .SLR_col_finish(SLRs_col_finish[9:0]));
    LineEngine #(.SCREEN_WIDTH(W), .SCREEN_HEIGHT(H), .LITTLEWORDIAN(LW)) le (
        .clk(clk), .rst(rst), .LE_ready(LE_ready), .LE_color_valid(LE_color_valid), .LE_color(LE_color),
        .LE_x0_valid(LE_x0_valid), .LE_y0_valid(LE_y0_valid), .LE_x1_valid(LE_x1_valid), .LE_y1_valid(LE_y1_valid),
        .LE_point(LE_point), .LE_trigger(LE_trigger), .LE_frame(LE_frame),
        .SLR_ready(SLRs_ready[1]), .SLR_valid(SLRs_valid[1]), .SLR_frame(SLRs_frame[63:32]),
        .SLR_color_edge(SLRs_color_edge[63:32]), .SLR_color_fill(SLRs_color_fill[63:32]),
        .SLR_row(SLRs_row[19:10]), .SLR_col_start(SLRs_col_start[19:10]), .SLR_col_finish(SLRs_col_finish[19:10]));

    reg         full = 0;
    wire        caf_full = full, wdf_full = full;
    wire        caf_wren, wdf_wren;
    wire [ 30:0] caf_addr;
    wire [127:0] wdf_data;
    wire [ 15:0] wdf_mask;
    ScanLineRunner #(.SCREEN_WIDTH(W), .SCREEN_HEIGHT(H), .LITTLEWORDIAN(LW), .SLR_COUNT(2)) slr (
        .clk(clk), .rst(rst),
        .caf_full(caf_full), .wdf_full(wdf_full), .caf_wren(caf_wren), .caf_addr(caf_addr),
        .wdf_wren(wdf_wren), .wdf_data(wdf_data), .wdf_mask(wdf_mask),
        .SLRs_ready(SLRs_ready), .SLRs_valid(SLRs_valid), .SLRs_frame(SLRs_frame),
        .SLRs_color_edge(SLRs_color_edge), .SLRs_color_fill(SLRs_color_fill),
        .SLRs_row(SLRs_row), .SLRs_col_start(SLRs_col_start), .SLRs_col_finish(SLRs_col_finish));

    // ---- FIFO / DDR model ----
    reg [31:0] fb  [0:1048575];   // DUT result, [row*1024 + col]
    reg [31:0] gold[0:1048575];   // reference
    integer seed = 11, errors = 0, writes = 0;
    reg [30:0] q_addr [0:15];     // queued caf addresses (FIFO), beats pair up in order
    integer qh = 0, qt = 0, beat = 0;
    reg [127:0] beat1_data; reg [15:0] beat1_mask;
    always @(negedge clk) begin
        // one "full" for both FIFOs, as RequestController drives bpas_waf_full/bpas_wdf_full
        full <= ({$random(seed)} % 5) == 0;
    end
    task apply(input [30:0] a, input [127:0] d1, input [15:0] m1, input [127:0] d2, input [15:0] m2);
        reg [31:0] byteaddr; reg [255:0] d; reg [31:0] m; integer p, w, row, col0, k;
    begin
        byteaddr = {a[28:0], 3'b000};   // DDR byte address (CPU address bits 27:0)
        if (byteaddr[31:22] != {4'h0, FRAME} || byteaddr[4:0] != 0) begin
            errors = errors + 1;
            if (errors < 20) $display("FAIL: DDR write to %h outside frame %h or unaligned", byteaddr, FRAME_ADDR);
        end else begin
            row = byteaddr[21:12]; col0 = {byteaddr[11:5], 3'b000};
            d = {d1, d2}; m = {m1, m2};
            for (p = 0; p < 8; p = p + 1) begin
                w = LW ? 7 - p : p;          // 32-bit slot of pixel p within {beat1,beat2}
                for (k = 0; k < 4; k = k + 1)
                    if (!m[4*w + k]) fb[row*1024 + col0 + p][8*k +: 8] = d[32*w + 8*k +: 8];
            end
            writes = writes + 1;
        end
    end
    endtask
    always @(posedge clk) begin
        if (caf_wren && !caf_full) begin q_addr[qt % 16] = caf_addr; qt = qt + 1; end
        if (wdf_wren && !wdf_full) begin
            if (beat == 0) begin beat1_data = wdf_data; beat1_mask = wdf_mask; beat = 1; end
            else begin
                if (qh == qt) begin errors = errors + 1; $display("FAIL: write data without an address"); end
                else begin apply(q_addr[qh % 16], beat1_data, beat1_mask, wdf_data, wdf_mask); qh = qh + 1; end
                beat = 0;
            end
        end
    end

    // ---- stimulus + reference ----
    task do_fill(input [31:0] color);
        integer x, y;
    begin
        wait (FF_ready && LE_ready && slr.SLR_MASTER_ready); @(negedge clk);
        FF_color = color; FF_frame = FRAME_ADDR | 32'h0012_3456; FF_valid = 1;
        @(negedge clk); FF_valid = 0;
        @(negedge clk);
        for (y = 0; y < H; y = y + 1) for (x = 0; x < W; x = x + 1)
            gold[y*1024 + x] = (x == 0 || x == W - 1) ? color : (32'hFF000000 | color);
        wait (FF_ready);
    end
    endtask

    task pulse(input integer which, input [9:0] v);
    begin
        @(negedge clk); LE_point = v;
        case (which) 0: LE_x0_valid = 1; 1: LE_y0_valid = 1; 2: LE_x1_valid = 1; endcase
        @(negedge clk); {LE_x0_valid, LE_y0_valid, LE_x1_valid} = 0;
    end
    endtask

    // swline() from the comment at the end of gpu/LineEngine.v
    task ref_line(input integer x0, input integer y0, input integer x1, input integer y1, input [31:0] color);
        integer difXs, difYs, decrX, decrY, difXu, difYu, trn, flip, a0, a1, b0, b1, incB, negB, errA, posA, error, a, b, errorB;
    begin
        difXs = x1 - x0; difYs = y1 - y0;
        decrX = difXs < 0; decrY = difYs < 0;
        difXu = decrX ? -difXs : difXs; difYu = decrY ? -difYs : difYs;
        trn = difYu > difXu; flip = trn ? decrY : decrX;
        if (trn) begin
            if (flip) begin a0 = y1; b0 = x1; a1 = y0; b1 = x0; end else begin a0 = y0; b0 = x0; a1 = y1; b1 = x1; end
        end else begin
            if (flip) begin a0 = x1; b0 = y1; a1 = x0; b1 = y0; end else begin a0 = x0; b0 = y0; a1 = x1; b1 = y1; end
        end
        incB = b1 > b0;
        negB = incB ? (b0 - b1) : (b1 - b0);
        errA = a1 - a0; posA = errA + negB; error = errA >>> 1;
        a = a0; b = b0;
        while (a <= a1) begin
            if (trn) gold[a*1024 + b] = color; else gold[b*1024 + a] = color;
            errorB = error + negB;
            a = a + 1;
            if (errorB < 0) begin b = incB ? b + 1 : b - 1; error = error + posA; end
            else error = errorB;
        end
    end
    endtask

    task do_line(input integer x0, input integer y0, input integer x1, input integer y1, input [31:0] color);
    begin
        wait (LE_ready && FF_ready); @(negedge clk);
        LE_color = color; LE_color_valid = 1;
        @(negedge clk); LE_color_valid = 0;
        pulse(0, x0); pulse(1, y0); pulse(2, x1);
        @(negedge clk); LE_point = y1; LE_y1_valid = 1; LE_frame = FRAME_ADDR; LE_trigger = 1;
        @(negedge clk); LE_y1_valid = 0; LE_trigger = 0;
        ref_line(x0, y0, x1, y1, color);
        @(negedge clk); wait (LE_ready);
    end
    endtask

    integer i, x, y, bad, xa, ya, xb, yb;
    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("GpuRaster_tb.vcd"); $dumpvars(0, GpuRaster_tb); end
        for (i = 0; i < 1048576; i = i + 1) begin fb[i] = 32'hDEADBEEF; gold[i] = 32'hDEADBEEF; end
        repeat (5) @(posedge clk); rst = 0; repeat (3) @(posedge clk);

        do_fill(32'h00203040);
        do_line(  2,   4,  10,   6, 32'h117F0000);
        do_line(  0,   0, 799, 599, 32'h227F0000);
        do_line(799,   0,   0, 599, 32'h337F0000);
        do_line(500, 599,   0,   0, 32'h447F0000);
        do_line(  0,   0, 400, 599, 32'h557F0000);
        do_line(200, 200, 100, 500, 32'h667F00FF);
        do_line(400, 250, 400, 350, 32'h77FF3018);
        do_line(400, 300, 400, 300, 32'h88FFFFFF);
        do_line(  7, 100, 792, 100, 32'h00ABCDEF);   // horizontal across many 8-pixel chunks
        do_line(  9, 101,  14, 101, 32'h00ABCDEF);   // within one chunk
        for (i = 0; i < `NLINES; i = i + 1) begin
            xa = {$random(seed)} % W; ya = {$random(seed)} % H; xb = {$random(seed)} % W; yb = {$random(seed)} % H;
            do_line(xa, ya, xb, yb, $random(seed));
        end
        repeat (20) @(posedge clk);
        while (!slr.SLR_MASTER_ready) @(posedge clk);

        bad = 0;
        for (y = 0; y < 1024; y = y + 1) for (x = 0; x < 1024; x = x + 1)
            if (fb[y*1024 + x] !== gold[y*1024 + x]) begin
                bad = bad + 1;
                if (bad <= 10) $display("FAIL: pixel (%0d,%0d) = %h, expected %h", x, y, fb[y*1024 + x], gold[y*1024 + x]);
            end
        if (bad) errors = errors + 1;
        if (qh != qt || beat != 0) begin errors = errors + 1; $display("FAIL: unmatched FIFO traffic (%0d addresses, %0d data pairs)", qt, qh); end
`ifdef FORCE_FAIL
        errors = errors + 1;
`endif
        $display("LW=%0d: %0d DDR writes, %0d mismatching pixels", LW, writes, bad);
        if (errors == 0) $display("PASS: GPU raster path (FrameFiller + LineEngine + ScanLineRunner)");
        else $display("FAIL: GPU raster path, %0d errors", errors);
        $finish;
    end
endmodule
