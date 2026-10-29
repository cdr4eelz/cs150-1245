// FrameFiller_check_tb: self-checking test of gpu/FrameFiller.v. Each fill must produce one
// ScanLineRunner request per row, rows 0..H-1 in order, each spanning columns 0..W-1, with the
// frame clipped to a 4 MB boundary in DDR space (0x1xxxxxxx), edge color = color and fill
// color = 0xFF000000 | color; FF_ready must drop while filling and come back after.
// Random SLR back-pressure; several fills with different colors/frames; prints PASS/FAIL.
`timescale 1ns/1ps
module FrameFiller_check_tb;
    localparam W = 800, H = 600;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    wire        FF_ready;
    reg         FF_valid = 0;
    reg  [31:0] FF_color = 0, FF_frame = 0;
    reg         SLR_ready = 0;
    wire        SLR_valid;
    wire [31:0] SLR_frame, SLR_color_edge, SLR_color_fill;
    wire [ 9:0] SLR_row, SLR_col_start, SLR_col_finish;

    FrameFiller #(.SCREEN_WIDTH(W), .SCREEN_HEIGHT(H)) DUT (
        .clk(clk), .rst(rst),
        .FF_ready(FF_ready), .FF_valid(FF_valid), .FF_color(FF_color), .FF_frame(FF_frame),
        .SLR_ready(SLR_ready), .SLR_valid(SLR_valid), .SLR_frame(SLR_frame),
        .SLR_color_edge(SLR_color_edge), .SLR_color_fill(SLR_color_fill),
        .SLR_row(SLR_row), .SLR_col_start(SLR_col_start), .SLR_col_finish(SLR_col_finish));

    integer seed = 3, errors = 0, rows = 0, next_row = 0, fills = 0;
    reg [31:0] exp_frame, exp_color;
    always @(negedge clk) SLR_ready <= ($random(seed) & 3) != 0;
    always @(posedge clk) if (SLR_valid && SLR_ready) begin
        if (SLR_row !== next_row || SLR_col_start !== 0 || SLR_col_finish !== W - 1 ||
            SLR_frame !== exp_frame || SLR_color_edge !== exp_color || SLR_color_fill !== (32'hFF000000 | exp_color)) begin
            errors = errors + 1;
            if (errors < 20) $display("FAIL: fill %0d: row %0d (want %0d) cols %0d..%0d frame %h edge %h fill %h (want frame %h color %h)",
                fills, SLR_row, next_row, SLR_col_start, SLR_col_finish, SLR_frame, SLR_color_edge, SLR_color_fill, exp_frame, exp_color);
        end
        if (FF_ready) begin errors = errors + 1; $display("FAIL: FF_ready high while filling"); end
        next_row = next_row + 1; rows = rows + 1;
    end

    task fill(input [31:0] color, input [31:0] frame);
        integer t;
    begin
        wait (FF_ready); @(negedge clk);
        exp_color = color; exp_frame = {4'h1, frame[27:22], 22'b0}; next_row = 0;
        FF_color = color; FF_frame = frame; FF_valid = 1;
        @(negedge clk);
        FF_valid = 0; FF_color = 32'bx; FF_frame = 32'bx;
        t = 0;
        while (!FF_ready && t < 10 * W * H) begin @(negedge clk); t = t + 1; end
        if (next_row !== H) begin
            errors = errors + 1;
            $display("FAIL: fill %0d produced %0d rows, expected %0d", fills, next_row, H);
        end
        repeat (5) @(negedge clk);
        if (SLR_valid) begin errors = errors + 1; $display("FAIL: SLR_valid while idle"); end
        fills = fills + 1;
    end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("FrameFiller_check_tb.vcd"); $dumpvars(0, FrameFiller_check_tb); end
        repeat (5) @(posedge clk);
        rst = 0;
        fill(32'h00123456, 32'h10400000);
        fill(32'h00FFFFFF, 32'h1FFFFFFF);   // frame clipped to 0x1FC00000
        fill(32'hAB000000, 32'h00000000);   // top byte of color passes to the edge color
        fill(32'h00000000, 32'h13ABCDEF);
`ifdef FORCE_FAIL
        errors = errors + 1;
`endif
        $display("%0d fills, %0d rows checked", fills, rows);
        if (errors == 0) $display("PASS: FrameFiller");
        else $display("FAIL: FrameFiller, %0d errors", errors);
        $finish;
    end
endmodule
