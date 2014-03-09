/*
*** Command procesor module handles logic for parsing graphics commands ***
  FrameFiller -- One graphics command:
    1. Write fill-color & automatically trigger
  LineEngine -- Three graphics commands:
    1. Write start-point (* IGNORING trigger on start-point)
    2. Write end-point (* ALWAYS trigger on end-point)
    3. Write line-color
     *(IGNORING: If trigger bit set in command, also fire on start or end point)
  Enhancements:
    1. Chain a series of points into optionally triggering lines.
    2. Apply "clip" region such that FrameFiller becomes RectangleFiller.
    3. Text? Other shapes? Filled shapes (mathematically bound)?
    4. Stamp with bitmap (raster rather than geometric manipulation).
    5. Bit to specify "non-blocking" issue of commands (parallel execution).
*/

`include "gpcommands.vh"

//TODO:Eliminate FIFO for less latency?
//TODO:Preview code chunks for C_STOP (not just zero data), and stop fetching ASAP
//TODO:Fault response?

module GraphicsProcessor #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
//TODO: Implement LITTLEWORDIAN
)(
    input clk,
    input rst,
//GraphicsProcessor interface:
    output          GP_ready,
    input           GP_valid,
    input   [ 31:0] GP_code,
    input   [ 31:0] GP_frame,
    output  [  5:0] GP_procframe,
    output          GP_interrupt,
//DDR FIFOs (read-only for GP):
    input           rdf_valid,
    input           af_full,
    input   [127:0] rdf_dout,
    output          rdf_rd_en,
    output          af_wr_en,
    output  [ 30:0] af_addr_din,
//FrameFiller interface:
    input           FF_ready,
    output          FF_valid,
    output  [ 31:0] FF_color,
    output  [ 31:0] FF_frame,
//LineEngine interface:
    input           LE_ready,
    output          LE_color_valid,
    output  [ 31:0] LE_color,
    output          LE_x0_valid,
    output          LE_y0_valid,
    output          LE_x1_valid,
    output          LE_y1_valid,
    output  [  9:0] LE_point,
    output          LE_trigger,
    output  [ 31:0] LE_frame
);

   //Your code goes here. GL HF.

//Three semi-independent machines coordinating with each other:
//    MASTER: Master state of GPCODE chunk processing.
//    SUB: Sub-states for sub/multi-CMD instructions like with points.
//          (Note LINE takes 3xINST and each point fed in 2-cycles)
//    FIFO: Fetch 256-bit chunks from memory & present 32-bit INST stream.
//Chose for GP, FF, LE, etc. to EACH capture own copy of frame upon trigger.

//Master States:
    localparam S_DEAD       = 0;
    localparam S_RESET      = 1;
    localparam S_IDLE       = 2;
//  localparam S_INIT       = 3;
    localparam S_PROCESS    = 4; //"RUNNING"
//  localparam S_KILL       = 5;
    localparam S__LAST      = 4;

//Sub-States:
    localparam SS_TOP   = 0;
    localparam SS_X0    = 1;
    localparam SS_Y0    = 2;
    localparam SS_XX    = 3;
    localparam SS_YY    = 4;
    localparam SS__LAST = 4;

//Engine CMD codes (computed/composite state):
    localparam C_WAIT       = 0; //FIFO dry, Engine-Wait, etc. but not FOUL
    localparam C_STOP       = 1;
    localparam C_FF_RGB     = 2;
    localparam C_LE_RGB     = 3;  //css==0
    localparam C_LE_X0      = 4;  //css==1
    localparam C_LE_Y0      = 5;  //css==2
    localparam C_LE_XX      = 6;  //css==3
    localparam C_LE_YY      = 7;  //css==4
//  localparam C_ST_WAIT    = 8;
//  localparam C_ST_X0      = 9;
//  localparam C_ST_Y0      =10;
    localparam C__LAST      = 7;

    reg  [C__LAST:0] hot_cmd;
    reg  [ 5:0] framebits;  //Insist on aligning with multiples of 0x0040_0000
    reg  [22:0] code_chunk; //256-bit chunk # within 256MB range of DDR (8 x 32-bit words each)
    reg  [ 2:0] code_skips; //Offset of first 32-bit CODE within 256-bit chunk (skip on fifo read)
    reg  [ 3:0] ns, cs = S_DEAD;
    reg  [ 2:0] nss, css = 0; //SubState
    reg  INST_advance;
//FIFO Pending Count, Need Count

//TODO:Let pending read responses clear upon reset
    wire ENGINES_ready = (FF_ready && LE_ready);
    assign GP_ready = (cs == S_IDLE); // && ENGINES_ready);
    assign GP_procframe = framebits;

    wire fifo_low, fifo_full, fifo_empty;

//Trigger values shared between state transitions & outputs (often 1-cycle duration)
    //T_DEAD = INITIAL upon FPGA config
    wire T_RSET   = (rst); //Might OR with T_DONE???
    wire T_IDLE   = (!rst && fifo_empty); //TODO:Use reset_delay FF or CNT
    wire T_INIT   = (GP_ready && GP_valid);
    wire T_DONE   = (hot_cmd[C_STOP]);

    assign GP_interrupt = T_DONE; //TODO:Replace with reg asserted cleanly for 1-cycle

//INSTruction RAW decode (includes invalid/inactive signals)
    wire INST_valid;
    wire [31:0] INST;
    wire [ 7:0] inst_gop    = INST[`IX_INST_GOP];
    wire [31:0] inst_color  = {8'd0, INST[`IX_INST_COLOR]};
    wire [ 9:0] inst_pointX = INST[`IX_POINT_X];
    wire [ 9:0] inst_pointY = INST[`IX_POINT_Y];
//  wire        inst_trigger = INST[`IX_POINT_TRIG]);

//ENGINE & state-based RAW feeds (includes invalid/inactive signals):
    wire engine_x = (hot_cmd[C_LE_X0] || hot_cmd[C_LE_XX]);
    wire [ 9:0] engine_point = (engine_x) ? inst_pointX : inst_pointY;
    wire [31:0] engine_color = inst_color;
    wire [31:0] engine_frame = {4'h1,framebits,22'd0};

//MAP specific ENGINEs as appropriate (or continuous when no harm):
    assign FF_valid   = (hot_cmd[C_FF_RGB]);
    assign FF_color   = engine_color,
            FF_frame  = engine_frame;
    assign LE_color_valid = (hot_cmd[C_LE_RGB]),
            LE_x0_valid   = (hot_cmd[C_LE_X0]),
            LE_y0_valid   = (hot_cmd[C_LE_Y0]),
            LE_x1_valid   = (hot_cmd[C_LE_XX]),
            LE_y1_valid   = (hot_cmd[C_LE_YY]),
            LE_trigger    = LE_y1_valid; //inst_trigger;
    assign LE_color   = engine_color,
            LE_point  = engine_point,
            LE_frame  = engine_frame;

//SUB State-Machine (outputs: hot_cmd & INST_advance)
    always @(*) begin
        nss = css; //Hold sub-state if unassigned
        hot_cmd = 0;
        INST_advance = 1'b0;
        if ((cs == S_PROCESS) && (INST_valid)) begin
            case (css)
                SS_TOP: if (ENGINES_ready) begin //All TOP INST (even STOP) wait on ALL
                    //TODO:Make exception for C_STOP (wait during S_RESET instead)
                    INST_advance = 1'b1;
                    hot_cmd[C_STOP]   = (inst_gop == `GOP_STOP);
                    hot_cmd[C_FF_RGB] = (inst_gop == `GOP_FILL);
                    hot_cmd[C_LE_RGB] = (inst_gop == `GOP_LINE);
                    nss = (inst_gop == `GOP_LINE) ? SS_X0 : SS_TOP;
                    //TODO:Capture GOP so Sub-states can overlay other engines
                end
                SS_X0: begin
                    hot_cmd[C_LE_X0] = 1'b1;
                    nss = SS_Y0;
                end
                SS_Y0: begin
                    INST_advance = 1'b1;
                    hot_cmd[C_LE_Y0] = 1'b1;
                    nss = SS_XX;
                end
                SS_XX: begin
                    hot_cmd[C_LE_XX] = 1'b1;
                    nss = SS_YY;
                end
                SS_YY: begin
                    INST_advance = 1'b1;
                    hot_cmd[C_LE_YY] = 1'b1;
                    nss = SS_TOP;
                end
                default: nss = SS_TOP;
            endcase
        end
    end
    always @(posedge clk) begin
        if (T_RSET) css <= SS_TOP; else css <= nss;
    end

//MASTER State-Machine (
    always @(*) begin
        ns = cs; //Default: Hold prior state if UNASSIGNED
        case (cs)
            S_DEAD:   if (T_RSET) ns = S_RESET; //Redundant with machine reset
            S_RESET:  if (T_IDLE) ns = S_IDLE;
            S_IDLE:   if (T_INIT) ns = S_PROCESS;
            S_PROCESS:if (T_DONE) ns = S_RESET;
            default:  ns = S_DEAD; //Default for UNTRAPPED
        endcase
    end
    always @(posedge clk) begin
        if (T_RSET) cs <= S_RESET; else cs <= ns;

        if (T_INIT) begin //No harm to ignore T_RSET
            //            GP-code[31:28] -- Ignore hi-nibble which likely specified D-Cache from CPU's POV
            code_chunk <= GP_code[27:5]; //Take enough to address a 256-bit-chunk in DDR
            code_skips <= GP_code[ 4:2]; //Take 3-bits for 32-bit word offset within chunk
            //            GP_code[ 1:0] -- Ignore lo 2-bits (would specify byte within a word)
            framebits <= `FRAME_BITS(GP_frame); //Either addr style
        end else begin
            if (!af_full && af_wr_en) begin
                code_chunk <= (code_chunk + 1); //1 x "chunk" af-request -=> 2 x 128-bit rdf-response
            end
            //TODO:ADJUST "pending" by simultaneous INC x2 vs. DEC x1 on fifo_write
        end
    end


//FIFO fetching GPCode chunks & presenting as 32-bit INSTruction stream
    wire fifo_reset = (cs == S_RESET);
    wire fifo_write = (cs == S_PROCESS) && (rdf_valid && rdf_rd_en);
    wire [ 4:0] wr_count;

    assign fifo_low = !(|wr_count[4:2] || fifo_full); //(wr_count < 4);
    assign af_wr_en = (cs == S_PROCESS) && !af_full && fifo_low;
    assign af_addr_din = {6'd0, code_chunk, 2'b00}; //Chunk DDR address (64-bit "resolution")
    assign rdf_rd_en = 1'b1; //Never argue with RequestController about our slot(s)!

    gpcode_fifo GPCODE_FIFO (
        .wr_clk(clk),         // input wr_clk
        .wr_rst(fifo_reset),  // input wr_rst
        .full   (fifo_full),    // output full
        .wr_en  (fifo_write),   // input wr_en
        .din    (rdf_dout),     // input [127 : 0] din
        .wr_data_count(wr_count), // output [4 : 0] wr_data_count

        .rd_clk(clk),         // input rd_clk
        .rd_rst(fifo_reset),  // input rd_rst
        .empty  (fifo_empty),   // output empty
        .valid  (INST_valid),   // output valid
        .dout   (INST),         // output [31 : 0] dout
        .rd_en  (INST_advance)  // input rd_en
    );


//synthesis translate_off
    always @(posedge clk) if (!rst) begin
        if (fifo_write)
            $display("fifo-W: data=%h %h %h %h (full=%b count=%0d)",
                     rdf_dout[127:96], rdf_dout[95:64], rdf_dout[63:32],
                     rdf_dout[31:0], fifo_full, wr_count);
        if (INST_valid || INST_advance)
            $display("fifo-R: %h gop=%h  valid=%b advance=%b (rst=%b empty=%b)",
                     INST, inst_gop, INST_valid, INST_advance, fifo_reset, fifo_empty);
    end
//synthesis translate_on

endmodule
