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

module GraphicsProcessor #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
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
//TODO:Ensure CMD doesn't match except when comparison is valid
//TODO:Eliminate FIFO ???
//TODO:Preview code chunks for C_STOP (not just zero data), and stop fetching ASAP
//TODO:Fault response?

//NOTE:Decided to "capture" frame upon trigger of GP and each engine (FF, LE)

   //Your code goes here. GL HF.

//Three semi-independent machines coordinating with each other:
//    CODE-processor: Master state of GPCODE chunk processing.
//    cmd-FEEDer:: Fetch from memory & present CMD stream
//    CMD-processor: Sub-states of CMD "parsing" & issue to ENGINEs
//
//HIST: Considered assembling all info then "fireing" action...
//      Chose to SEND PIECEMEAL since CMDs present themselves in useable order.

//Master States
    localparam S_DEAD       = 0;
    localparam S_RESET      = 1;
    localparam S_IDLE       = 2;
//  localparam S_INIT       = 3;
    localparam S_PROCESS    = 4; //"RUNNING"
//  localparam S_KILL       = 5;

//TODO:Use two-way one-hot "matrix"???

//Computed Sub-States (force NULL if not in S_PROCESS)
    localparam C_NULL           = 0; //FIFO dry, Engine-Wait, etc. but not FOUL
    localparam C_FILL_COLOR     = 1;
    localparam C_LINE_COLOR     = 2;
    localparam C_LINE_POINTX0   = 3;
    localparam C_LINE_POINTY0   = 4;
    localparam C_LINE_POINTX    = 5;
    localparam C_LINE_POINTY    = 6;
//  localparam C_WAIT_STAMP     = 7;
//  localparam C_STAMP_POINTX   = 8;
//  localparam C_STAMP_POINTY   = 9;
    localparam C_STOP           =10;


    reg  [ 5:0] framebits;  //Insist on aligning with multiples of 0x0040_0000
    reg  [22:0] code_chunk; //256-bit chunk # within 256MB range of DDR (8 x 32-bit words each)
    reg  [ 2:0] code_skips; //Offset of first 32-bit CODE within 256-bit chunk (skip on fifo read)
    reg  [ 3:0] ns, cs = S_DEAD;
//FIFO Pending Count, Need Count, Fetch
//TODO:Clear pending read responses
    assign GP_ready = (cs == S_IDLE);
    assign GP_procframe = framebits;

    wire fifo_low, fifo_full, fifo_empty;

//Trigger values shared between state transitions & outputs (often 1-cycle duration)
    //T_DEAD = INITIAL upon FPGA config
    wire T_RSET   = (rst); //Might OR with T_DONE???
    wire T_IDLE   = (!rst && fifo_empty); //TODO:Use reset_delay FF or CNT
    wire T_INIT   = (GP_ready && GP_valid);
    wire T_DONE   = (CMD == C_STOP);

    assign GP_interrupt = T_DONE; //TODO:Replace with reg asserted cleanly for 1-cycle

//INSTruction RAW decode (includes invalid/inactive signals)
    wire INST_valid, INST_advance;
    wire [31:0] INST;
    wire [ 7:0] inst_gop    = INST[`IX_INST_GOP];
    wire [31:0] inst_color  = {8'd0, INST[`IX_INST_COLOR]};
    wire [ 9:0] inst_pointX = INST[`IX_POINT_X];
    wire [ 9:0] inst_pointY = INST[`IX_POINT_Y];
//  wire        inst_trigger = INST[`IX_POINT_TRIG]);

//ENGINE & state-based RAW feeds (includes invalid/inactive signals):
    wire engine_x = (CMD == C_LINE_POINTX0) || (CMD == C_LINE_POINTX);
    wire [ 9:0] engine_point = (engine_x) ? inst_pointX : inst_pointY;
    wire [31:0] engine_color = inst_color;
    wire [31:0] engine_frame = {4'h1,framebits,22'd0};

//MAP specific ENGINEs as appropriate (or continuous when no harm):
    assign FF_valid   = (CMD == C_FILL_COLOR);
    assign FF_color   = engine_color,
            FF_frame  = engine_frame;
    assign LE_color_valid = (CMD == C_LINE_COLOR),
            LE_x0_valid   = (CMD == C_LINE_COLOR),
            LE_y0_valid   = 0,
            LE_x1_valid   = 0,
            LE_y1_valid   = 0,
            LE_trigger    = LE_y1_valid; //inst_trigger;
    assign LE_color   = engine_color,
            LE_point  = engine_point,
            LE_frame  = engine_frame;


//MASTER State-Machine
    always @(*) begin
        ns = cs; //Default: Hold prior state if UNASSIGNED
        case (cs)
            S_DEAD:   if (T_RSET) ns = S_RESET; //Redundant with reset above
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

    assign fifo_low = !(|wr_count[4:2]); //(wr_count < 4);
    assign af_wr_en = (cs == S_PROCESS) && fifo_low; //Must assert for af_full to go low!
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

endmodule
