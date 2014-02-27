
/*
 Command procesor module that handles the logic for parsing the graphics commands
 Three graphics commands for line engine:
 1. Write start point
 2. Write end-point
 3. Write line color
 If trigger bit set in command, command will also fire on start or end point
 Frame buffer fill will trigger automatically
 
 */
`include "gpcommands.vh"

module GraphicsProcessor #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input clk,
    input rst,
//DDR FIFOs (read-only):
    input           rdf_valid,
    input           af_full,
    input   [127:0] rdf_dout,
    output          rdf_rd_en,
    output          af_wr_en,
    output  [ 30:0] af_addr_din,
//LineEngine interface:
    input           LE_ready,
    output  [ 31:0] LE_color,
    output  [  9:0] LE_point,
    output          LE_color_valid,
    output          LE_x0_valid,
    output          LE_y0_valid,
    output          LE_x1_valid,
    output          LE_y1_valid,
    output          LE_trigger,
    output  [ 31:0] LE_frame,
//FrameFiller interface:
    input           FF_ready,
    output          FF_valid,
    output  [ 23:0] FF_color,
    output  [ 31:0] FF_frame,
//GraphicsProcessor interface:
    output          GP_ready,
    input           GP_valid,
    input   [ 31:0] GP_frame,
    input   [ 31:0] GP_code,
    output          GP_interrupt
);

   //Your code goes here. GL HF.

    reg  [22:0] cmd_chunk;   //256-bit chunk # within 256MB range of DDR (8 x 32-bit words)
    reg  [ 2:0] cmd_index;   //Specific 32-bit word within 256-bit chunk
    reg  [ 5:0] framebits;   //Insist on aligning with multiples of 0x0040_0000

    localparam S_DEAD       = 0;
    localparam S_RESET      = 1;
    localparam S_IDLE       = 2;
    localparam S_LAUNCH     = 3;
    localparam S_RUN        = 4;
    localparam S_DONE       = 5;

    reg  [3:0] ns, cs = S_DEAD;
//Individual action "strobes" (often just 1-cycle with a state transition)

    always @(posedge clk or posedge rst) begin
        if (rst) cs <= S_RESET; //Avoid reset of registers guarded by state
        else cs <= ns;
    end

    always @(posedge clk) begin
        if (ns == S_LAUNCH) begin //Transitioning to RUN
            cmd_chunk <= GP_code[27:5]; //Hi nibble ignored, reset is enough for 256-bit-chunk
            cmd_index <= GP_code[ 4:2]; //Lo 2-bits would be byte, take next 3-bits for word-in-chunk
            framebits <= (|GP_frame[31:28]) ? GP_frame[27:22] : GP_frame[5:0]; //Either addr style
        end
    end

    always @(*) begin
        ns = cs; //Default for unassigned transition
        case (cs)
            S_RESET: ns = S_IDLE; //Make sure no premature action simply on ns=S_IDLE
            S_IDLE, S_DONE: ns = (GP_valid) ? S_LAUNCH : S_IDLE;
            S_RUN, S_LAUNCH: ns = (LE_ready && FF_ready) ? S_DONE : S_RUN;
            default: ns = S_DEAD; //Default for un-trapped state
        endcase
    end

    assign GP_ready = (cs == S_IDLE) || (cs == S_DONE);
    assign GP_interrupt = (ns == S_DONE); //Transitioning to DONE

    assign af_addr_din = {6'd0, framebits, cmd_chunk, 2'b00}; //Chunk DDR address

   //output assignment placeholders - delete these later

   assign LE_color = 0;
   assign LE_point = 0;

   assign LE_color_valid = 0;
   assign LE_x0_valid = 0;
   assign LE_y0_valid = 0;
   assign LE_x1_valid = 0;
   assign LE_y1_valid = 0;

   assign LE_trigger = 0;
   assign LE_frame = 0;

   //frame filler processor interface
   assign FF_valid  = 0;
   assign FF_color = 0;
   assign FF_frame = 0;

   //DRAM request controller interface
   assign rdf_rd_en = 0;

   assign af_wr_en = 0;

endmodule
