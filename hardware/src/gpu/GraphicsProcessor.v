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
//TODO:Preview code chunks for CC_STOP (not just zero data), and stop fetching ASAP
//TODO:Fault response?

module GraphicsProcessor #(
    parameter USE_SLR=0,
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
//DDR FIFOs (read-only for GP cmd):
    input           rdf_valid,
    input           af_full,
    input   [127:0] rdf_dout,
    output          rdf_rd_en,
    output          af_wr_en,
    output  [ 30:0] af_addr_din,
//DDR FIFOs (write-only): [if USE_SLR]
    input           bypass_af_full,
    input           bypass_wdf_full,
    output  [ 30:0] bypass_af_addr_din,
    output          bypass_af_wr_en,
    output  [127:0] bypass_wdf_din,
    output  [ 15:0] bypass_wdf_mask_din,
    output          bypass_wdf_wr_en,
//FrameFiller interface: [if !USE_SLR]
    input           FF_ready,
    output          FF_valid,
    output  [ 31:0] FF_color,
    output  [ 31:0] FF_frame,
//LineEngine interface: [if !USE_SLR]
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

//Master-States:
    localparam [1:0]
        MS_DEAD     = 0, //Initial or fault (requires explicit reset)
        MS_RSET     = 1, //Performing or coming out of reset
        MS_IDLE     = 2, //Ready for GPCode initiation
        MS_PROC     = 3; //Processing GPCode block (to MS_RSET when done)
    localparam MS__LAST = 3;

//Sub-States:
    localparam [2:0]
        SS_TOP      = 0, //First or only INSTruction part
        SS_X0       = 1, //Sub-CMDs from separate
        SS_Y0       = 2, //  INSTs and/or within
        SS_XX       = 3, //  INSTs trailing initial
        SS_YY       = 4; //  INST at SS_TOP
    localparam SS__LAST = 4;

//FIFO-States:
    localparam
        FS_READY    = 0, //Can fetch if other conditions right
    //TODO:Add FS_FETCH  (& FS_START???)
        FS_READ1    = 1, //Awaiting 1st read 128-bits
        FS_READ2    = 2; //Awaiting 2nd read 128-bits
    localparam FS__LAST = 2;

//Key State Registers
    reg  [ 1:0] ns_M, cs_M = MS_DEAD; //Master-State
    reg  [ 2:0] ns_S, cs_S = SS_TOP;  //Sub-State
    //TODO:One/Zero-hot MS_ & SS_ also
    reg  [FS__LAST:0] ns_F, cs_F = (1<<FS_READY); //FIFO-State
    reg  [ 5:0] framebits;  //Insist on aligning with multiples of 0x0040_0000
    reg  [22:0] code_chunk; //256-bit chunk # within 256MB range of DDR (8 x 32-bit words each)
    reg  [ 2:0] code_skips; //Offset of first 32-bit CODE within 256-bit chunk (skip on fifo read)
    reg  rst_r;
    always @(posedge clk) rst_r <= rst;


    wire fifo_valid;
    wire ENGINES_ready;
    wire INST_valid    = (fifo_valid && (cs_M==MS_PROC)); //TODO:"Reset" on !MS_PROC???
    wire CMD_advance   = (INST_valid && ENGINES_ready);


//INSTruction RAW decode (includes invalid/inactive signals)
    wire [31:0] INST;
    wire [ 7:0] INST_gop    = INST[`IX_INST_GOP];
    wire [31:0] INST_color  = {8'd0, INST[`IX_INST_COLOR]};
    wire [ 9:0] INST_pointX = INST[`IX_POINT_X];
    wire [ 9:0] INST_pointY = INST[`IX_POINT_Y];
//  wire        INST_trigger = INST[`IX_POINT_TRIG]);


//  reg  hot_GOP_err;
    reg  [`GOP__LAST:0] hot_GOP_cal, hot_GOP_reg;
    wire [`GOP__LAST:0] hot_GOP;
    wire hot_GOP_sel, hot_GOP_val;
    assign hot_GOP_sel = (cs_S==SS_TOP); //Check INST_valid later after MUX
    assign hot_GOP_val = (CMD_advance && hot_GOP_sel);
    always @(*) begin
//      hot_GOP_err = 1'b0;
        case (INST_gop) //If big/slow, maybe barrel-shift or ROM lookup.
            `GOP_STOP, `GOP_FILL, `GOP_LINE:   //If sparse, let it prune,
                hot_GOP_cal = (1 << INST_gop); //  or make new constants.
            default: begin
                hot_GOP_cal = `GOP_STOP;
//              hot_GOP_err = 1'b1; //This is RAW signal
            end
        endcase
    end
    always @(posedge clk) if (hot_GOP_val)   hot_GOP_reg <= hot_GOP_cal;
    assign hot_GOP         = (hot_GOP_sel) ? hot_GOP_cal :  hot_GOP_reg;


//Triggers for state transitions & Mealy outputs (usually 1-cycle duration)
    //   T_DEAD   = INITIAL upon FPGA config
    wire T_RESET  = (rst); //TODO:OR with T_STOPS to piggyback on sync-reset???
wire fifo_empty; //TODO:FIFO-State embed all fifo info (also check FULL)
    wire T_READY  = (!rst_r && fifo_empty); //FIFO-State influences T_READY
    wire T_START  = (GP_ready && GP_valid); //MASTER-State alone for ready/valid enable
    wire T_STOPS  = (hot_GOP_val && hot_GOP[`GOP_STOP]); //Sub-State triggers T_STOPS


    assign GP_ready     = (cs_M==MS_IDLE);
    assign GP_procframe = `FRAME_BITS(GP_frame); //Pass NEXT value through! (was framebits)
    assign GP_interrupt = T_STOPS; //TODO:Ensure clean for most of 1-cycle


//Sub-State machine & Mealy outputs: CMD_advance, INST_advance
    wire INST_advance = (CMD_advance && !cs_S[0]); //EVENs: SS_TOP||SS_Y0||SS_YY
    always @(*) begin
        ns_S = cs_S; //Hold current state until valid
        case (cs_S) //Just a ring shifter with extra enable test!
            SS_TOP: if (INST_gop==`GOP_LINE) ns_S = SS_X0; //else SS_TOP
            SS_X0:  ns_S = SS_Y0;
            SS_Y0:  ns_S = SS_XX;
            SS_XX:  ns_S = SS_YY;
            SS_YY:  ns_S = SS_TOP;
        endcase
        //GOP-LatchieMux:(cs_S==SS_TOP)
        //RING-SHIFTER (TOP=>X0=>Y0=>XX=>YY=>TOP...)
        //ENABLE:((cs_S!=SS_TOP)||(INST_gop==`GOP_LINE))&&CMD_advance
        //Optionally invert TOP in/out so reset state is all zeros
    end
    //TODO:Make exception for GOP_STOP (wait during MS_RSET instead)
    always @(posedge clk) begin
        if (T_RESET) cs_S <= SS_TOP;
        else if (CMD_advance) cs_S <= ns_S;
    end


//MASTER State-Machine
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            MS_DEAD: if (T_RESET) ns_M = MS_RSET; //Redundant with machine reset
            MS_RSET: if (T_READY) ns_M = MS_IDLE;
            MS_IDLE: if (T_START) ns_M = MS_PROC;
            MS_PROC: if (T_STOPS) ns_M = MS_RSET;
        endcase
    end
    always @(posedge clk) begin
        if (T_RESET) cs_M <= MS_RSET; else cs_M <= ns_M;
    end
    always @(posedge clk) begin
        if (T_START) begin //Capture incoming values
            //            GP-code[31:28] -- Ignore hi-nibble which likely specified D-Cache from CPU's POV
            code_chunk <= GP_code[27:5]; //Take enough to address a 256-bit-chunk in DDR
            code_skips <= GP_code[ 4:2]; //Take 3-bits for 32-bit word offset within chunk
            //            GP_code[ 1:0] -- Ignore lo 2-bits (would specify byte within a word)
            framebits <= `FRAME_BITS(GP_frame); //Either addr style
        end else begin
            if (!af_full && af_wr_en) begin //Advance for next chunk
                code_chunk <= (code_chunk + 1); //1 x "chunk" af-request -=> 2 x 128-bit rdf-response
            end
            //TODO:ADJUST "pending" by simultaneous INC x2 vs. DEC x1 on fifo_write
        end
    end


//FIFO State-Machine
    always @(*) begin
        ns_F = cs_F; //Default: Hold prior state if UNASSIGNED
        case (cs_F)
        //TODO:New states on the way!
            (1<<FS_READY): if (!af_full && af_wr_en) ns_F = (1<<FS_READ1);
            (1<<FS_READ1): if (rdf_valid) ns_F = (1<<FS_READ2);
            (1<<FS_READ2): if (rdf_valid) ns_F = (1<<FS_READY);
        endcase
    end
    always @(posedge clk) begin
        if (T_START) cs_F <= (1<<FS_READY); else cs_F <= ns_F;
//$display("FIFO-STATE: %b  af_full:%b af_wr_en:%b rdf_valid:%b af_addr_din:%h",
//         cs_F, af_full, af_wr_en, rdf_valid, af_addr_din);
    end


//FIFO fetching GPCode chunks & presenting as 32-bit INSTruction stream
//TODO:Early first fetch address mux on T_START
    wire fifo_full, prog_empty;
    wire [ 4:0] wr_count;
    wire fifo_low   = !(|wr_count[4:2] || fifo_full); //(wr_count < 4);
    wire fifo_reset = (cs_M==MS_RSET);
    wire fifo_write = (cs_M==MS_PROC) && (rdf_valid && rdf_rd_en);

    //NOTE:Don't base af_wr_en on af_full when using RequestController!!!
    assign af_wr_en     = (cs_M==MS_PROC) && cs_F[FS_READY] && fifo_low;
    assign af_addr_din  = {6'd0, code_chunk, 2'b00}; //Chunk addr (64-bit "resolution")
    assign rdf_rd_en    = (cs_F[FS_READ1] || cs_F[FS_READ2]);

    gpcode_fifo GPCODE_FIFO (
        .wr_clk(clk),         // input wr_clk
        .wr_rst(fifo_reset),  // input wr_rst
        .full   (fifo_full),      // output full
        .wr_en  (fifo_write),     // input wr_en
        .din    (rdf_dout),   // input [127 : 0] din
        .wr_data_count(wr_count), // output [4 : 0] wr_data_count

        .rd_clk(clk),         // input rd_clk
        .rd_rst(fifo_reset),  // input rd_rst
        .empty  (fifo_empty),     // output empty
        .prog_empty(prog_empty),  // output prog_empty
        .valid  (fifo_valid),     // output valid
        .dout   (INST),           // output [31 : 0] dout
        .rd_en  (INST_advance)    // input rd_en
    );


//MAP ENGINEs as appropriate (or continuous/junk when no harm):
    wire engine_x = cs_S[0]; //ODDs: SS_X0||SS_XX
    wire [ 9:0] engine_point = (engine_x) ? INST_pointX : INST_pointY;
    wire [31:0] engine_color = INST_color;
    wire [31:0] engine_frame = {4'h1,framebits,22'd0};

    assign FF_valid       = (hot_GOP_val && hot_GOP[`GOP_FILL]);
    assign FF_color   = engine_color,
            FF_frame  = engine_frame;

    assign LE_color_valid = (hot_GOP_val && hot_GOP[`GOP_LINE]),
            LE_x0_valid   = (CMD_advance && hot_GOP[`GOP_LINE] && (cs_S==SS_X0)),
            LE_y0_valid   = (CMD_advance && hot_GOP[`GOP_LINE] && (cs_S==SS_Y0)),
            LE_x1_valid   = (CMD_advance && hot_GOP[`GOP_LINE] && (cs_S==SS_XX)),
            LE_y1_valid   = (CMD_advance && hot_GOP[`GOP_LINE] && (cs_S==SS_YY)),
            LE_trigger    = LE_y1_valid; //INST_trigger;
    assign LE_color   = engine_color,
            LE_point  = engine_point,
            LE_frame  = engine_frame;

generate if (USE_SLR) begin:_USE_SLR_

    wire [ 31:0] SLR_frame;
    wire [ 31:0] SLR_color_edge;
    wire [ 31:0] SLR_color_fill;
    wire         SLR_ready;
    wire         SLR_valid;
    wire [  9:0] SLR_row;
    wire [  9:0] SLR_col_start;
    wire [  9:0] SLR_col_finish;

    wire line_ready_internal;

    LineEngine #(
        .USE_SLR(1),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) le(
        .clk(clk),
        .rst(fifo_reset),
    //SLR interface (write-only):
        .SLR_frame      (SLR_frame),
        .SLR_color_fill (SLR_color_fill),
        .SLR_color_edge (SLR_color_edge),
        .SLR_ready      (SLR_ready),
        .SLR_valid      (SLR_valid),
        .SLR_row        (SLR_row),
        .SLR_col_start  (SLR_col_start),
        .SLR_col_finish (SLR_col_finish),
    //Line control <=> CPU:
        .LE_ready(line_ready_internal),
        .LE_color_valid(line_color_valid),
        .LE_color(line_color),
        .LE_x0_valid(line_x0_valid),
        .LE_y0_valid(line_y0_valid),
        .LE_x1_valid(line_x1_valid),
        .LE_y1_valid(line_y1_valid),
        .LE_point(line_point),
        .LE_trigger(line_trigger),
        .LE_frame(line_frame),
    //DDR FIFOs (write-only):
        .af_full(1'b1), .af_addr_din(), .af_wr_en(),
        .wdf_full(1'b1), .wdf_din(), .wdf_mask_din(), .wdf_wr_en()
    );

    ScanLineRunner #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) slr(
        .clk(clk),
        .rst(fifo_reset),
    //DDR FIFOs (write-only):
        .af_full        (bypass_af_full),
        .wdf_full       (bypass_wdf_full),
        .af_addr_din    (bypass_af_addr_din),
        .af_wr_en       (bypass_af_wr_en),
        .wdf_din        (bypass_wdf_din),
        .wdf_mask_din   (bypass_wdf_mask_din),
        .wdf_wr_en      (bypass_wdf_wr_en),
    //SLR interface:
        .SLR_frame      (SLR_frame),
        .SLR_color_fill (SLR_color_fill),
        .SLR_color_edge (SLR_color_edge),
        .SLR_ready      (SLR_ready),
        .SLR_valid      (SLR_valid),
        .SLR_row        (SLR_row),
        .SLR_col_start  (SLR_col_start),
        .SLR_col_finish (SLR_col_finish)
    );

    assign ENGINES_ready = (FF_ready && line_ready_internal);

end else begin:_NO_SLR_

    assign ENGINES_ready = (FF_ready && LE_ready);

    assign bypass_af_wr_en = 1'b0, bypass_wdf_wr_en = 1'b0;

end endgenerate


//synthesis translate_off
    always @(posedge clk) if (!rst) begin
        if (fifo_write)
            $display("fifo-W: data=%h %h %h %h (full=%b count=%0d)",
                     rdf_dout[127:96], rdf_dout[95:64], rdf_dout[63:32],
                     rdf_dout[31:0], fifo_full, wr_count);
        if (fifo_valid || INST_advance)
            $display("fifo-R: %h gop=%h  valid=%b advance=%b (rst=%b empty=%b)",
                     INST, INST_gop, fifo_valid, INST_advance, fifo_reset, fifo_empty);
    end
//synthesis translate_on

endmodule
