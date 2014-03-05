
/*
 Command procesor module that handles the logic for parsing the graphics commands.
 Three graphics commands for line engine:
   1. Write start point
   2. Write end-point
   3. Write line color
 If trigger bit set in command, command will also fire on start or end point.
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
    output  [ 31:0] FF_color,
    output  [ 31:0] FF_frame,
//GraphicsProcessor interface:
    output          GP_ready,
    input           GP_valid,
    input   [ 31:0] GP_frame,
    input   [ 31:0] GP_code,
    output  [  5:0] GP_procframe,
    output          GP_interrupt
);
//TODO:Decide how many spots shall capture COLOR & FRAME values!
//TODO:Ensure CMD doesn't match except when comparison is valid
//TODO:Use 10-bit frame#s
//TODO:Eliminate FIFO ???
//TODO:Preview code chunks for C_STOP (not just zero data), and stop fetching early

   //Your code goes here. GL HF.

    reg  [ 5:0] framebits;  //Insist on aligning with multiples of 0x0040_0000
    reg  [22:0] code_chunk; //256-bit chunk # within 256MB range of DDR (8 x 32-bit words)
    reg  [ 2:0] code_skips; //Offset of first 32-bit CODE within 256-bit chunk (skip on fifo read)

//Instruction decode ranges (doesn't mean they are valid or active)
    wire [ 7:0] inst_gop = INST[IX_INST_GOP];
    wire [31:0] inst_color = {8'd0, INST[IX_INST_COLOR]};
    wire [31:0] inst_frame = {4'h1,framebits,22'd0};
    wire [ 9:0] inst_point = (point_part) ? INST[IX_POINT_X] : INST[IX_POINT_Y];
    wire        inst_trigger = INST[IX_POINT_TRIG]);

//Trigger values shared between state transitions & outputs (often 1-cycle duration)
    //T_DEAD = INITIAL
    wire T_RST   = (rst); //Might OR with T_DONE???
    wire T_READY = (!rst && fifo_empty);
    wire T_INIT  = (GP_ready && GP_valid);
    wire T_DONE  = (CMD == C_STOP);

//Master States
    localparam S_DEAD       = 0;
    localparam S_RESET      = 1;
    localparam S_IDLE       = 2;
//  localparam S_INIT       = 3;
    localparam S_PROCESS    = 4; //"RUNNING"
//  localparam S_KILL       = 5;
//Command Sub-States (force NULL if not in S_PROCESS)
    localparam C_NULL           = 0; //write_rrrFIFO dry, etc. but not FOUL or elsewhere
    localparam C_FILL_COLOR     = 1; //WAIT: FillEngine ready signal!!!
    localparam C_LINE_COLOR     = 2;
    localparam C_LINE_POINTX0   = 3;
    localparam C_LINE_POINTY0   = 4;
    localparam C_LINE_POINTX    = 5;
    localparam C_LINE_POINTY    = 6;
//  localparam C_STAMP_COLOR    = 7;
//  localparam C_STAMP_POINT    = 8;
//  localparam C_STAMP_POINT    = 9;
//FIFO Sub-States (force NULL if not in S_PROCESS)
    localparam F_NULL           = 0;

    reg  [3:0] ns, cs = S_DEAD;

    //Go ahead and drive all these continuously even with junk:
    assign LE_color = inst_color;
    assign LE_point = inst_point;
    assign LE_frame = inst_frame;
    assign FF_color = inst_color;
    assign FF_frame = inst_frame;
    //Then ensure these are active only as appropriate:
    assign FF_valid = (GOP == C_FILL);
    assign LE_color_valid   = (GOP == C_FILL);
    assign LE_x0_valid      = 0;
    assign LE_y0_valid      = 0;
    assign LE_x1_valid      = 0;
    assign LE_y1_valid      = 0;
    assign LE_trigger = (GOP == C_FILL) && inst_trigger;

//WAIT ON: LE_ready (MUX wait-sources)

    assign af_addr_din = {6'd0, framebits, cmd_chunk, 2'b00}; //Chunk DDR address
    assign rdf_rd_en = 0;
    assign af_wr_en = 0;
    assign rdf_valid = 0;

    assign GP_ready = (cs == S_IDLE);
    assign GP_procframe = framebits;
    assign GP_interrupt = T_DONE;

    wire fifo_active = (cs == S_PROCESS);

    always @(posedge clk) begin
        if (T_RESET) cs <= S_RESET; else cs <= ns;
        if (T_INIT) begin
            //            GP-code[31:28] -- Ignore hi-nibble which likely specified D-Cache from CPU's POV
            code_chunk <= GP_code[27:5]; //Take enough to address a 256-bit-chunk in DDR
            code_index <= GP_code[ 4:2]; //Take 3-bits for 32-bit word offset within chunk
            //            GP_code[ 1:0] -- Ignore lo 2-bits (would specify byte within a word)
            framebits <= (|GP_frame[31:28]) ? GP_frame[27:22] : GP_frame[5:0]; //Either addr style
        end
    end

    always @(*) begin
        ns = cs; //Default for unassigned transition
        case (cs)
            S_DEAD: if (T_RESET) ns = S_RESET; //Redundant with reset above
            S_RESET: if (T_IDLE) ns = S_IDLE;
            S_IDLE: if (T_INIT) ns = S_PROCESS;
            S_PROCESS: if (T_DONE) ns = S_RESET;
            default: ns = S_DEAD; //Default for un-trapped state
        endcase
    end

gpcode_fifo GPCODE_FIFO (
    .wr_clk(clk), // input wr_clk
    .wr_rst(fifo_reset), // input wr_rst
    .din(din), // input [127 : 0] din
    .wr_en(wr_en), // input wr_en
    .full(full), // output full
    .almost_full(almost_full), // output almost_full
    .prog_full(prog_full) // output prog_full
    .overflow(overflow), // output overflow

    .rd_clk(clk), // input rd_clk
    .rd_rst(fifo_reset), // input rd_rst
    .valid(cmd_valid), // output valid
    .rd_en(cmd_rd_en), // input rd_en
    .dout(cmd_data), // output [31 : 0] dout
    .empty(fifo_empty), // output empty
    .underflow(fifo_underflow), // output underflow
);

endmodule
