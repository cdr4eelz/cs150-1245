// LineEngine_check_tb: self-checking test of gpu/LineEngine.v (one pixel per ScanLineRunner
// request). For every line it collects the pixels the engine sends and checks, independently
// of Bresenham tie-breaking details:
//   - exactly max(|dx|,|dy|)+1 pixels, one per step along the major axis, covering it fully
//   - every pixel within 1/2 pixel of the ideal line along the minor axis (so the endpoints
//     are exact) and neighbors differ by at most 1 on the minor axis
//   - SLR frame/edge/fill colors, col_start == col_finish
// The SLR side applies random back-pressure. Lines: the original bench's set (some
// reaching x=1023/y=767), octant/edge cases, and NLINES random lines. Prints PASS/FAIL.
`timescale 1ns/1ps
module LineEngine_check_tb;
`ifndef NLINES
  `define NLINES 200
`endif
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    wire        LE_ready;
    reg         LE_color_valid = 0, LE_x0_valid = 0, LE_y0_valid = 0, LE_x1_valid = 0, LE_y1_valid = 0;
    reg  [31:0] LE_color = 0, LE_frame = 0;
    reg  [ 9:0] LE_point = 0;
    reg         LE_trigger = 0;
    reg         SLR_ready = 0;
    wire        SLR_valid;
    wire [31:0] SLR_frame, SLR_color_edge, SLR_color_fill;
    wire [ 9:0] SLR_row, SLR_col_start, SLR_col_finish;

    LineEngine DUT (
        .clk(clk), .rst(rst),
        .LE_ready(LE_ready), .LE_color_valid(LE_color_valid), .LE_color(LE_color),
        .LE_x0_valid(LE_x0_valid), .LE_y0_valid(LE_y0_valid),
        .LE_x1_valid(LE_x1_valid), .LE_y1_valid(LE_y1_valid),
        .LE_point(LE_point), .LE_trigger(LE_trigger), .LE_frame(LE_frame),
        .SLR_ready(SLR_ready), .SLR_valid(SLR_valid), .SLR_frame(SLR_frame),
        .SLR_color_edge(SLR_color_edge), .SLR_color_fill(SLR_color_fill),
        .SLR_row(SLR_row), .SLR_col_start(SLR_col_start), .SLR_col_finish(SLR_col_finish));

    integer seed = 7, errors = 0, lines = 0, pixels = 0;
    integer npix;
    reg [9:0] px [0:2047];
    reg [9:0] py [0:2047];
    reg [31:0] exp_frame, exp_color;
    reg        collecting = 0;

    // SLR sink: random ready, record each accepted pixel
    always @(posedge clk) begin
        if (SLR_valid && SLR_ready && collecting) begin
            if (npix < 2048) begin px[npix] = SLR_col_start; py[npix] = SLR_row; end
            npix = npix + 1;
            if (SLR_col_finish !== SLR_col_start || SLR_frame !== exp_frame || SLR_color_edge !== exp_color ||
                SLR_color_fill !== {exp_color[31:24], exp_color[23:16] >> 1, exp_color[15:8] >> 1, exp_color[7:0]}) begin
                errors = errors + 1;
                if (errors < 20) $display("FAIL: SLR fields row=%0d cols=%0d..%0d frame=%h edge=%h fill=%h (want frame %h color %h)",
                    SLR_row, SLR_col_start, SLR_col_finish, SLR_frame, SLR_color_edge, SLR_color_fill, exp_frame, exp_color);
            end
        end
    end
    always @(negedge clk) SLR_ready <= ($random(seed) & 3) != 0;

    task pulse_point(input integer which, input [9:0] v);
    begin
        @(negedge clk);
        LE_point = v;
        case (which) 0: LE_x0_valid = 1; 1: LE_y0_valid = 1; 2: LE_x1_valid = 1; 3: LE_y1_valid = 1; endcase
        @(negedge clk);
        {LE_x0_valid, LE_y0_valid, LE_x1_valid, LE_y1_valid} = 0;
    end
    endtask

    reg [9:0]  seen [0:1023];   // minor coordinate per major coordinate (+ valid bit below)
    reg        have [0:1023];
    task check_line(input integer x0, input integer y0, input integer x1, input integer y1);
        integer dx, dy, adx, ady, i, a, b, a0, b0, da, db, dev, amin, amax, bad, k;
    begin
        dx = x1 - x0; dy = y1 - y0;
        adx = dx < 0 ? -dx : dx; ady = dy < 0 ? -dy : dy;
        bad = 0;
        for (k = 0; k < 1024; k = k + 1) have[k] = 0;
        if (ady > adx) begin a0 = y0; b0 = x0; da = dy; db = dx; end
        else           begin a0 = x0; b0 = y0; da = dx; db = dy; end
        amin = (da < 0) ? a0 + da : a0; amax = (da < 0) ? a0 : a0 + da;
        if (npix != (adx > ady ? adx : ady) + 1) begin
            bad = 1; $display("FAIL: line (%0d,%0d)-(%0d,%0d): %0d pixels, expected %0d", x0, y0, x1, y1, npix, (adx > ady ? adx : ady) + 1);
        end
        for (i = 0; i < npix && i < 2048; i = i + 1) begin
            a = (ady > adx) ? py[i] : px[i];
            b = (ady > adx) ? px[i] : py[i];
            if (a < amin || a > amax || have[a]) begin
                if (!bad) $display("FAIL: line (%0d,%0d)-(%0d,%0d): pixel (%0d,%0d) out of range or repeated", x0, y0, x1, y1, px[i], py[i]);
                bad = 1;
            end else begin
                have[a] = 1; seen[a] = b;
                // |(b-b0) - db*(a-a0)/da| <= 1/2   <=>   |2*((b-b0)*da - db*(a-a0))| <= |da|
                dev = 2 * ((b - b0) * da - db * (a - a0));
                if (dev < 0) dev = -dev;
                if (dev > (da < 0 ? -da : da)) begin
                    if (!bad) $display("FAIL: line (%0d,%0d)-(%0d,%0d): pixel (%0d,%0d) is more than 1/2 off the line", x0, y0, x1, y1, px[i], py[i]);
                    bad = 1;
                end
            end
        end
        for (a = amin; a < amax && !bad; a = a + 1)
            if (have[a] && have[a+1] && (seen[a+1] > seen[a] + 1 || seen[a] > seen[a+1] + 1)) begin
                $display("FAIL: line (%0d,%0d)-(%0d,%0d): gap between steps %0d and %0d", x0, y0, x1, y1, a, a + 1);
                bad = 1;
            end
        if (bad) errors = errors + 1;
        lines = lines + 1; pixels = pixels + npix;
    end
    endtask

    task draw(input integer x0, input integer y0, input integer x1, input integer y1, input [31:0] color, input [31:0] frame);
    begin
        wait (LE_ready); @(negedge clk);
        exp_color = color; exp_frame = {4'h1, frame[27:22], 22'b0};
        LE_color = color; LE_color_valid = 1;
        @(negedge clk); LE_color_valid = 0; LE_color = 32'bx;
        pulse_point(0, x0); pulse_point(1, y0); pulse_point(2, x1);
        npix = 0; collecting = 1;
        @(negedge clk);
        LE_point = y1; LE_y1_valid = 1; LE_frame = frame; LE_trigger = 1;
        @(negedge clk);
        LE_y1_valid = 0; LE_trigger = 0; LE_point = 10'bx; LE_frame = 32'bx;
        @(posedge clk); #1;
        while (!LE_ready) begin @(posedge clk); #1; end
        repeat (2) @(posedge clk);
        collecting = 0;
        check_line(x0, y0, x1, y1);
    end
    endtask

    integer i, xa, ya, xb, yb;
    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("LineEngine_check_tb.vcd"); $dumpvars(0, LineEngine_check_tb); end
        repeat (10) @(posedge clk);
        rst = 0;
        repeat (3) @(posedge clk);
        // the original LineEngineTestbench set
        draw(   2,   4,   10,   6, 32'h117F0000, 32'h10400000);
        draw(   0,   0, 1023, 767, 32'h227F0000, 32'h10400000);
        draw(1000, 700,    0,   0, 32'h337F0000, 32'h10400000);
        draw( 500, 700,    0,   0, 32'h447F0000, 32'h10400000);
        draw(   0,   0,  400, 652, 32'h557F0000, 32'h10400000);
        draw( 200, 200,  100, 500, 32'h667F00FF, 32'h10400000);
        draw( 400, 250,  400, 350, 32'h77FF3018, 32'h10400000);
        draw( 400, 300,  400, 300, 32'h88FFFFFF, 32'h10400000);
        // octants, axis-aligned, diagonals, edges of the 10-bit range
        draw(100, 100, 200, 130, 32'h00102030, 32'h10800000);
        draw(100, 100, 130, 200, 32'h00102030, 32'h10800000);
        draw(100, 100,   0, 130, 32'h00102030, 32'h10C00000);
        draw(100, 100,  70, 200, 32'h00102030, 32'h10C00000);
        draw(100, 100, 200,  70, 32'h00102030, 32'h11000000);
        draw(100, 100, 130,   0, 32'h00102030, 32'h11000000);
        draw(100, 100,   0,  70, 32'h00102030, 32'h11400000);
        draw(100, 100,  70,   0, 32'h00102030, 32'h11400000);
        draw(  0, 599, 799,   0, 32'h00FFFFFF, 32'h1F000000);
        draw(799,   0,   0, 599, 32'h00FFFFFF, 32'h1F000000);
        draw( 10,  10,  60,  60, 32'h00ABCDEF, 32'h10000000);
        draw( 60,  10,  10,  60, 32'h00ABCDEF, 32'h10000000);
        draw(  0, 300, 799, 300, 32'h00ABCDEF, 32'h10000000);
        draw(799, 301,   0, 301, 32'h00ABCDEF, 32'h10000000);
        draw(  5,   0,   5, 599, 32'h00ABCDEF, 32'h10000000);
        draw(  6, 599,   6,   0, 32'h00ABCDEF, 32'h10000000);
        draw(1023, 1023, 0,   0, 32'h00ABCDEF, 32'h10000000);
        draw(  0, 1023, 1023, 0, 32'h00ABCDEF, 32'h10000000);
        draw(  3,   4,   4,   6, 32'h00ABCDEF, 32'h10000000);
        draw(  0,   0,   1,   0, 32'h00ABCDEF, 32'h10000000);
        // random lines on an 800x600 screen
        for (i = 0; i < `NLINES; i = i + 1) begin
            xa = {$random(seed)} % 800; ya = {$random(seed)} % 600;
            xb = {$random(seed)} % 800; yb = {$random(seed)} % 600;
            if (i % 4 == 0) begin xb = xa + ({$random(seed)} % 9) - 4; yb = ya + ({$random(seed)} % 9) - 4; end
            if (xb < 0) xb = 0; if (yb < 0) yb = 0;
            draw(xa, ya, xb, yb, $random(seed), 32'h10000000 | ({$random(seed)} & 32'h0FC00000));
        end
`ifdef FORCE_FAIL
        errors = errors + 1;
`endif
        $display("%0d lines, %0d pixels checked", lines, pixels);
        if (errors == 0) $display("PASS: LineEngine");
        else $display("FAIL: LineEngine, %0d errors", errors);
        $finish;
    end
endmodule
