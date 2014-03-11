module FrameFiller #(
    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600
)(
    input           clk,
    input           rst,
//DDR FIFOs (write-only):
    input           af_full,
    output          af_wr_en,
    output [ 30:0]  af_addr_din,
    input           wdf_full,
    output          wdf_wr_en,
    output [ 15:0]  wdf_mask_din,
    output [127:0]  wdf_din,
//Fill control <=> CPU:
    output          FF_ready, //Can start issuing values/trigger
    input           FF_valid,   //Trigger drawing (FF_frame & FF_color captured)
    input  [ 31:0]  FF_color,   //8-zeros, 3 x 8-bit R/G/B
    input  [ 31:0]  FF_frame    //Frame-base (modulo 0x0040_0000)
);

//Your code goes here. GL HF DD DS

//NOTE: DDR addressible to 64-bit "resolution", meaning lo 3-bits of address stripped.
//      Also, 4x64=256-bits accessed per request, so ideal is 32-byte align (lo 5-bits zero).
//      Chosen approach simply imposes 32-byte alignment by clipping the frame base address.

    localparam S_DEAD   = 2'b00;
    localparam S_RESET  = 2'b01;
    localparam S_IDLE   = 2'b10;
    localparam S_RUN    = 2'b11;

    reg  [31:0] color;
    reg  [ 5:0] framebits;
    reg  [ 9:0] y, x;
    reg  [ 1:0] ns, cs = S_DEAD;

    //TODO:Teach offsets/edges for rectangle boundaries later...
    reg  [ 9:0] rL = 0, rR = (SCREEN_WIDTH  - 1);
    reg  [ 9:0] rT = 0, rB = (SCREEN_HEIGHT - 1);

    wire [31:0] head_addr = {4'h1, framebits, y[9:0], x[9:0], 2'b00}; //"Byte" address
    wire lastX = (x > (rR-4));
    wire lastY = (y > (rB-1));

    wire mem_ready = (!af_full && !wdf_full);
    wire mem_advance = (mem_ready && wdf_wr_en);

    assign af_wr_en  = ((cs == S_RUN) && !x[2]); //Skip address on odds's
    assign af_addr_din = {6'd0, head_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign wdf_wr_en = (cs == S_RUN); //Data & mask on odd & even
    assign wdf_din = {4{color}}; //Replicate same color on each write
    assign wdf_mask_din = {4{4'b0000}}; //Write all bytes on every write

    assign FF_ready  = (cs == S_IDLE);
    assign FF_start  = (FF_ready && FF_valid);

    always @(*) begin
        ns = cs; //Default for unassigned
        case (cs)
            S_RESET: ns = S_IDLE;
            S_IDLE: if (FF_start) ns = S_RUN;
            S_RUN: if (mem_advance && lastX && lastY) ns = S_RESET;
            default: ns = S_DEAD; //Default for untrapped
        endcase
    end

    always @(posedge clk) begin
        if (rst) cs <= S_RESET;
        else cs <= ns;

        if (FF_start) begin
            color <= FF_color;
            framebits <= FF_frame[27:22]; //Clip to standard frames
            y <= rT;
            x <= {rL[9:3],3'b00};
        end else if (mem_advance && lastX) begin
            y <= (y + 1);
            x <= {rL[9:3],3'b00};
        end else if (mem_advance) x <= (x + 4);
    end


//synthesis translate_off
    always @(posedge clk) begin
        if (FF_start) begin
            #1;
            $display("[=FILL=]: frame=%h color=%h (%0d,%0d,%0d)", framebits,
                     color, color[23:16], color[15:8], color[7:0]);
        end
    end

//synthesis translate_on

endmodule
