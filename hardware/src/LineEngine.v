
module LineEngine(
    input           clk,
    input           rst,
//DDR FIFOs (write-only):
    input           af_full,
    input           wdf_full,
    output  [ 30:0] af_addr_din,
    output          af_wr_en,
    output  [127:0] wdf_din,
    output  [ 15:0] wdf_mask_din,
    output          wdf_wr_en,
//Line control <=> CPU:
    output          LE_ready, //Can start issuing values/trigger
    input           LE_color_valid, //LE_color capture
    input   [ 31:0] LE_color,   //8-zeros, 3 x 8-bit R/G/B
    input           LE_x0_valid,//LE_point captured into x0
    input           LE_y0_valid,//  ... y0
    input           LE_x1_valid,//  ... x1
    input           LE_y1_valid,//  ... y1
    input   [  9:0] LE_point,   //Point data with each LE_[x0,y0,x1,y1]_valid
    input           LE_trigger, //Trigger drawing (LE_frame captured)
    input   [ 31:0] LE_frame    //Frame-base (modulo 0x0040_0000)
);

    // Implement Bresenham's line drawing algorithm here!

    localparam S_DEAD       = 0;
    localparam S_RESET      = 1;
    localparam S_IDLE       = 2;
    localparam S_LAUNCH     = 3;
    localparam S_RUN        = 4;
    localparam S_DONE       = 5;

    reg  [ 2:0] state = S_DEAD, state_next = S_IDLE;
    reg  [31:0] color;
    reg  [ 9:0] x0, y0, x1, y1;
    reg  [ 6:0] framebits;

    assign LE_ready = (state == S_IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) state <= S_RESET; //Avoid reset of registers guarded by state
        else state <= state_next;
    end

    always @(posedge clk) begin
        if (LE_ready) begin //Capture active inputs if not running
            if (LE_color_valid) color <= LE_color;
            if (LE_x0_valid) x0 <= LE_point;
            if (LE_y0_valid) y0 <= LE_point;
            if (LE_x1_valid) x1 <= LE_point;
            if (LE_y1_valid) y1 <= LE_point;
            if (LE_trigger) framebits <= LE_frame[27:22];
        end
    end

    // Remove these when you implement this module:
    assign af_wr_en = 1'b0;
    assign wdf_wr_en = 1'b0;

endmodule

/*
#define SWAP(x, y) (x ^= y ^= x ^= y)
#define ABS(x) (((x)<0) ? -(x) : (x))

void line(int x0, int y0, int x1, int y1) {
    char steep = (ABS(y1 - y0) > ABS(x1 - x0)) ? 1 : 0;
    if (steep) {
        SWAP(x0, y0);
        SWAP(x1, y1);
    }
    if (x0 > x1) {
        SWAP(x0, x1);
        SWAP(y0, y1);
    }
    int deltax = x1 - x0;
    int deltay = ABS(y1 - y0);
    int error = deltax / 2;
    int ystep;
    int y = y0
    int x;
    ystep = (y0 < y1) ? 1 : -1;
    for (x = x0; x <= x1; x++) {
        if (steep)
            plot(y,x);
        else
            plot(x,y);
        error = error - deltay;
        if (error < 0) {
            y += ystep;
            error += deltax;
        }
    }
}
*/