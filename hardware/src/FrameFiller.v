module FrameFiller #(
    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600
)(
    input           clk,
    input           rst,
//DDR FIFOs (write-only):
    input           af_full,
    input           wdf_full,
    output [127:0]  wdf_din,
    output          wdf_wr_en,
    output [ 30:0]  af_addr_din,
    output          af_wr_en,
    output [ 15:0]  wdf_mask_din,
//Fill control <=> CPU:
    output          FF_ready,
    input           FF_valid,
    input  [ 31:0]  FF_color,
    input  [ 31:0]  FF_frame //NOTE: Requires 32-byte alignment (low 5-bit stripped)
);

//Your code goes here. GL HF DD DS

//NOTE: DDR addressible to 64-bit "resolution", meaning lo 3-bits of address stripped.
//      Also, 4x64=256-bits accessed per request, so ideal is 32-byte align (lo 5-bits zero).
//      Chosen approach simply imposes 32-byte alignment by clipping the frame base address.

    //TODO:Teach offsets/edges for rectangle boundaries later...
    localparam S_DEAD   = 2'b00;
    localparam S_IDLE   = 2'b01;
    localparam S_RUN    = 2'b10;

    reg  [ 1:0] ns, cs = S_DEAD;
    reg  [31:0] color;
    reg  [ 5:0] framebits;
    reg  [ 9:0] y, x;
    wire [ 9:0] L = 0, R = SCREEN_WIDTH  - 1;
    wire [ 9:0] T = 0, B = SCREEN_HEIGHT - 1;
    wire lastX = (x > R); //TODO:Use special compare
    wire lastY = (y > B);
    wire mem_ready = (!af_full && !wdf_full);
    assign FF_ready  = (cs == S_IDLE);
    assign FF_start  = (FF_ready && FF_valid);
    assign af_wr_en  = (cs == S_RUN && !x[2]); //Skip address on odds's
    assign wdf_wr_en = (cs == S_RUN); //Data & mask on odd & even
    assign wdf_din = {4{color}}; //Replicate same color on each write
    assign wdf_mask_din = {4{4'b0000}}; //Write all bytes on every write

    always @(posedge clk) begin
        if (rst) cs <= S_IDLE;
        else if (FF_start) cs <= S_RUN;
        else if (mem_ready && lastX && lastY) cs <= S_IDLE;

        if (FF_start) {color, framebits} <= {FF_color, FF_frame[27:22]};

        if (FF_start) y <= T;
        else if (mem_ready && lastX) y <= y+1;

        if (FF_start || (mem_ready && lastX)) x <= {L[9:3],3'b00};
        else if (mem_ready) x <= x + 4;
    end

endmodule
