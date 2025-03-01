
module FrameFiller #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter SCANLINERUNNER=0
)(
    input           clk, rst,

//Fill control <=> GPU:
    output          FF_ready, //Can start issuing values/trigger
    input           FF_valid,   //Trigger drawing (FF_frame & FF_color captured)
    input  [ 31:0]  FF_color,   //8-zeros, 3 x 8-bit R/G/B
    input  [ 31:0]  FF_frame,   //Frame-base (modulo 0x0040_0000)

//DDR FIFOs (write-only): [if !SCANLINERUNNER]
    input           caf_full,
    input           wdf_full,
    output          caf_wren,
    output [ 27:0]  caf_addr,
    output          wdf_wren,
    output [ 15:0]  wdf_mask,
    output [127:0]  wdf_data,

//SLR control (write-only): [if SCANLINERUNNER]
    input           SLR_ready,
    output          SLR_valid,
    output  [ 31:0] SLR_frame,
    output  [ 31:0] SLR_color_edge,
    output  [ 31:0] SLR_color_fill,
    output  [  9:0] SLR_row,
    output  [  9:0] SLR_col_start,
    output  [  9:0] SLR_col_finish
);

//Your code goes here. GL HF DD DS

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, <rst>_r, unless really must sync-up release!
    end

//NOTE: DDR addressible to 64-bit "resolution", meaning lo 3-bits of address stripped.
//      Also, 4x64=256-bits accessed per request, so ideal is 32-byte align (lo 5-bits zero).
//      Chosen approach simply imposes 32-byte alignment by clipping the frame base address.

    localparam [1:0]
        S_DEAD   = 2'd0,
        S_RESET  = 2'd1,
        S_IDLE   = 2'd2,
        S_RUN    = 2'd3;

    reg  [ 1:0] ns, cs = S_DEAD;
    reg  [31:0] color_r;
    reg  [ 5:0] framebits;
    localparam [ 9:0] rL = 0, rR = (SCREEN_WIDTH  - 1),
                      rT = 0, rB = (SCREEN_HEIGHT - 1);

    wire T_DONE_FULL, T_DONE_LINE, T_DONE_PIX4;
    wire T_START = (FF_ready && FF_valid);

    assign FF_ready  = (cs == S_IDLE);

    always @(*) begin
        ns = cs; //Default for unassigned
        case (cs)
            S_RESET: ns = S_IDLE; //Gives 1-cycle in S_RESET after !rst_r
            S_IDLE:  if (T_START) ns = S_RUN;
            S_RUN:   if (T_DONE_FULL) ns = S_RESET;
            default: ns = S_DEAD; //Default for untrapped
        endcase
    end

    reg  [ 9:0] y, x;
    wire lastY = (y > (rB-1));
    wire lastX = (x > (rR-4));

    always @(posedge clk) begin
        if (rst_r) cs <= S_RESET;
        else cs <= ns;

        if (T_START) begin
            color_r <= FF_color;
            framebits <= FF_frame[27:22]; //Clip to standard frames
            y <= rT;
            x <= {rL[9:3],3'b00};
        end else if (T_DONE_LINE) begin
            y <= (y + 1);
            x <= {rL[9:3],3'b00};
        end else if (T_DONE_PIX4) begin
            x <= (x + 4);
        end
    end


generate if (SCANLINERUNNER) begin:_WITH_SLR_

    assign SLR_valid        = (cs == S_RUN),
            SLR_frame       = {4'h1, framebits[5:0], 22'b0},
            SLR_color_edge  = color_r,
            SLR_color_fill  = color_r,
            SLR_row         = y,
            SLR_col_start   = rL,
            SLR_col_finish  = rR;

    wire slr_advance = (SLR_ready && SLR_valid);

    assign T_DONE_PIX4 = 1'b0,
            T_DONE_LINE = slr_advance,
            T_DONE_FULL = slr_advance && lastY;

    assign caf_wren     = 1'b0,
            caf_addr    = 28'bx,
            wdf_wren    = 1'b0,
            wdf_data    = 128'bx,
            wdf_mask    = 16'bx;

end else begin:_NO_SLR_

    assign SLR_valid        = 1'b0,
            SLR_frame       = 32'bx,
            SLR_color_edge  = 32'bx,
            SLR_color_fill  = 32'bx,
            SLR_row         = 10'bx,
            SLR_col_start   = 10'bx,
            SLR_col_finish  = 10'bx;

    wire mem_advance = (!caf_full && !wdf_full && wdf_wren);

    assign T_DONE_PIX4 = mem_advance,
            T_DONE_LINE = mem_advance && lastX,
            T_DONE_FULL = mem_advance && lastX && lastY;

    wire [31:0] head_addr   = {4'h1, framebits, y[9:0], x[9:0], 2'b00}; //"Byte" address
    assign caf_wren         = ((cs == S_RUN) && !x[2]), //Skip address on odds's
            caf_addr        = {3'b000, head_addr[27:3]},  //Turn into 31-bit "DoubleWord" or DDR-address
            wdf_wren        = (cs == S_RUN),            //Data & mask on odd & even
            wdf_data        = {4{color_r}},             //Replicate same color on all 4 pixels of both writes
            wdf_mask        = {4{4'b0000}};             //Write all bytes on every write

end endgenerate

//synthesis translate_off
    always @(posedge clk) begin
        if (T_START) begin
            #1;
            $display("[=FILL=]: frame=%h color=%h (%0d,%0d,%0d)", framebits,
                     color_r, color_r[23:16], color_r[15:8], color_r[7:0]);
        end
    end
//synthesis translate_on

endmodule
