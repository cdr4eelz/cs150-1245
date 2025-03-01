//TODO:GP kill current work & start new GP_CODE
//TODO:Read-back GP_CODE address...chunk-address

/*
*** Command procesor module handles logic for parsing graphics commands ***
  FrameFiller -- One graphics command:
    1. Write fill-color & automatically trigger
  LineEngine -- Three graphics commands:
    1. Write line-color
    2. Write start-point (* IGNORING trigger on start-point)
    3. Write end-point (* ALWAYS trigger on end-point)
       *(IGNORING: If trigger bit mentioned in an old spec)
  Potential Enhancements:
    1. Chain a series of points into optionally triggering lines.
    2. Apply "clip" region such that FrameFiller becomes RectangleFiller.
    3. Text? Other shapes? Filled shapes (mathematically bound)?
    4. Stamp with bitmap (raster rather than geometric manipulation).
    5. Bit to specify "non-blocking" issue of commands (parallel execution).
*/

`include "gpcommands.vh"

//TODO:Preview code chunks for CC_STOP (not just zero data), and stop fetching ASAP

module GraphicsProcessor #(
    parameter LITTLEWORDIAN=1
)(
    input clk,
    input rst,

//DDR FIFOs (read-only for GP cmd):
    input           raf_full,
    output          raf_wren,
    output  [ 27:0] raf_addr, //WAS: [30:0]
    output          rdf_rden,
    input           rdf_wren,
    input   [127:0] rdf_data,

//GraphicsProcessor interface:
    input           GP_vcode, GP_vframe,
    input   [ 31:0] GP_wcode, GP_wframe,
    output  [ 31:0] GP_rcode,
    output  [  5:0]           GP_rframe,
    output          GP_ready,
    output          GP_fault,

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
    output  [ 31:0] LE_frame,

//ElipseEngine interface:
    input           EL_ready,
    output          EL_color_valid,
    output  [ 31:0] EL_color,
    output          EL_xc_valid,
    output          EL_yc_valid,
    output          EL_a_valid,
    output          EL_b_valid,
    output  [  9:0] EL_point,
    output          EL_trigger,
    output  [ 31:0] EL_frame
);

   //Your code goes here. GL HF.

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, <rst>_r, unless really must sync-up release!
    end

//Three semi-independent machines coordinating with each other:
//    MASTER: Master state of GPCODE chunk processing.
//    SUB   : Sub-states for sub/multi-CMD instructions like with points.
//            (Note LINE takes 3xINST and each point fed in 2-cycles)
//    CHUNK : Simple "DDRStage" grabs 256-bit chunks for 32-bit word access.
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

//Key State Registers
    reg  [ 1:0] ns_M, cs_M = MS_DEAD; //Master-State
    reg  [ 2:0] ns_S, cs_S = SS_TOP;  //Sub-State
    //TODO:One/Zero-hot MS_ & SS_ also
    reg  [ 5: 0] frame_bits;  //Insist on aligning with multiples of 0x0040_0000
    reg  [31:28] code_hinib;
    reg  [27: 5] code_chunk; //256-bit chunk # within 256MB range of DDR (8 x 32-bit words each)
    reg  [ 4: 2] code_index; //Offset of 32-bit CODE within 256-bit chunk
    reg          fault_r;

    wire ENGINES_ready, chunk_valid;
    wire INST_valid    = (chunk_valid && (cs_M==MS_PROC));
    wire CMD_advance   = (INST_valid && ENGINES_ready);
    wire chunk_advance = (!chunk_valid || (&code_index && CMD_advance));
    wire chunk_reset   = (rst_r || (cs_M==MS_IDLE)); //Reset chunk on IDLE to let pending read clear
    wire [255:0] chunk_data;

    assign GP_ready = (cs_M==MS_IDLE);
    assign GP_fault = fault_r;
    assign GP_rframe = frame_bits;
    assign GP_rcode = {code_hinib, code_chunk, code_index, 2'b0}; //4+23+3+2=32-bit


//INSTruction RAW decode (includes invalid/inactive signals)
    wire [ 7:0] code_shift  = (code_index << 5);
    wire [31:0] INST        = (chunk_data >> code_shift);
    wire [ 7:0] INST_gop    = INST[`IX_INST_GOP];
    wire [31:0] INST_color  = {8'd0, INST[`IX_INST_COLOR]};
    wire [ 9:0] INST_pointX = INST[`IX_POINT_X];
    wire [ 9:0] INST_pointY = INST[`IX_POINT_Y];
//  wire        INST_trigger = INST[`IX_POINT_TRIG]);

    reg  hot_GOP_err;
    reg  [`GOP__LAST:0] hot_GOP_cal, hot_GOP_reg;
    wire [`GOP__LAST:0] hot_GOP;
    wire hot_GOP_sel, hot_GOP_val;
    assign hot_GOP_sel = (cs_S==SS_TOP); //Check INST_valid later after MUX
    assign hot_GOP_val = (CMD_advance && hot_GOP_sel);

//Triggers for state transitions & Mealy outputs (usually 1-cycle duration)
    //   T_DEAD   = INITIAL upon FPGA config
    wire T_RESET  = (rst_r);
    wire T_READY  = (!rst_r && !rdf_rden); //Not ready until pending read clears
    wire T_START  = (GP_ready && GP_vcode); //MASTER-State alone for ready/valid enable
    wire T_STOPS  = (hot_GOP_val && hot_GOP[`GOP_STOP]); //Sub-State triggers T_STOPS

    always @(*) begin
        hot_GOP_cal = (1 << `GOP_STOP);
        hot_GOP_err = 1'b1; //This is RAW signal
        case (INST_gop) //If big/slow, maybe barrel-shift or ROM lookup.
            `GOP_FILL, `GOP_LINE, `GOP_ELIP: begin
                hot_GOP_cal = (1 << INST_gop);
                hot_GOP_err = 1'b0;
            end
            `GOP_STOP: begin
                hot_GOP_err = |INST; //Valid STOP must be all zeros
            end
        endcase
    end
    always @(posedge clk) begin
        if (T_RESET || T_START) fault_r <= 1'b0;
        else if (hot_GOP_val && hot_GOP_err) fault_r <= 1'b1;

        if (hot_GOP_val) hot_GOP_reg <= hot_GOP_cal;
    end
    assign hot_GOP = (hot_GOP_sel) ? hot_GOP_cal :  hot_GOP_reg;


//Sub-State machine & Mealy outputs: CMD_advance, INST_advance
    wire INST_advance = (CMD_advance && !cs_S[0]); //NOTE:FRAGILE! (EVENs: SS_TOP||SS_Y0||SS_YY)
    wire INST_dopoints = (INST_gop==`GOP_LINE) || (INST_gop==`GOP_ELIP);
    always @(*) begin
        ns_S = cs_S; //Hold current state until valid
        case (cs_S) //Just a ring shifter with extra enable test!
            SS_TOP: if (INST_dopoints) ns_S = SS_X0; //else SS_TOP
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
    always @(posedge clk) begin
        if (cs_M==MS_RSET) cs_S <= SS_TOP;
        else if (CMD_advance) cs_S <= ns_S;
    end


//MASTER State-Machine
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            //MS_DEAD: if (T_RESET) ns_M = MS_RSET; //Redundant with machine reset
            MS_RSET: if (T_READY) ns_M = MS_IDLE;
            MS_IDLE: if (T_START) ns_M = MS_PROC;
            MS_PROC: if (T_STOPS) ns_M = MS_RSET;
        endcase
    end
    always @(posedge clk) begin
        if (T_RESET) cs_M <= MS_RSET;
        else cs_M <= ns_M;

        if (T_START) begin //Capture incoming values
            code_hinib <= GP_wcode[31:28]; //Usually hi-nibble for D-Cache but grab for GP_proccode
            code_chunk <= GP_wcode[27: 5]; //Take enough to address a 256-bit-chunk in DDR
            code_index <= GP_wcode[ 4: 2]; //Take 3-bits for 32-bit word offset within chunk
            //            GP_wcode[ 1: 0]; -- Ignore lo 2-bits (would specify byte within a word)
            frame_bits <= `FRAME_BITS(GP_wframe); //Either frame addr or frame# allowed
        end else begin
            if (INST_advance) code_index <= (code_index + 3'd1); //"index" -=> 32-bit word within chunk
            if (raf_wren && !raf_full) code_chunk <= (code_chunk + 23'd1); //"chunk" -=> 2 x 128-bit
        end
    end


//FETCH GPCode chunks & present as 32-bit INSTruction stream
    assign raf_addr  = {3'd0, code_chunk, 2'b00}; //WAS: 3'd0  Chunk addr in 64-bit "resolution"
    assign raf_wren  = (cs_M==MS_PROC) && !rdf_rden && chunk_advance;
    //NOTE:Don't base raf_wren on !raf_full when using RequestController!!!

    DDRStage #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) ddr_stage (
        .clk(clk), .rst(chunk_reset), //MS_RSET waits until !rdf_rden
        .raf_full(raf_full),  //Advances if (!raf_full && raf_wren)
        .raf_wren(raf_wren), //Ignored if rdf_rden; resets chunk_valid regardless of raf_full
        .rdf_rden(rdf_rden),
        .rdf_wren(rdf_wren),
        .rdf_data(rdf_data),
        .chunk_valid(chunk_valid),
        .chunk_data(chunk_data)
    );


//MAP ENGINEs as appropriate (or continuous/junk when no harm):
    wire engine_x = cs_S[0]; //ODDs: SS_X0||SS_XX
    wire [ 9:0] engine_point = (engine_x) ? INST_pointX : INST_pointY;
    wire [31:0] engine_color = INST_color;
    wire [31:0] engine_frame = {4'h1,frame_bits,22'd0};

    assign FF_valid   = (hot_GOP_val && hot_GOP[`GOP_FILL]);
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

    assign EL_color_valid = (hot_GOP_val && hot_GOP[`GOP_ELIP]),
            EL_xc_valid   = (CMD_advance && hot_GOP[`GOP_ELIP] && (cs_S==SS_X0)),
            EL_yc_valid   = (CMD_advance && hot_GOP[`GOP_ELIP] && (cs_S==SS_Y0)),
            EL_a_valid    = (CMD_advance && hot_GOP[`GOP_ELIP] && (cs_S==SS_XX)),
            EL_b_valid    = (CMD_advance && hot_GOP[`GOP_ELIP] && (cs_S==SS_YY)),
            EL_trigger    = EL_b_valid; //INST_trigger;
    assign EL_color   = engine_color,
            EL_point  = engine_point,
            EL_frame  = engine_frame;

    assign ENGINES_ready = (FF_ready && LE_ready && EL_ready);


//synthesis translate_off
    always @(posedge clk) if (!rst_r) begin
        if (raf_wren)
            $display("stage-F: addr=%h full=%b",
                     raf_addr, raf_full
            );
        if (rdf_wren || rdf_rden)
            $display("stage-W: wren=%b rden=%b data=%h.%h.%h.%h",
                     rdf_wren, rdf_rden,
                     rdf_data[127:96], rdf_data[95:64],
                     rdf_data[63:32], rdf_data[31:0]
            );
        if (INST_advance)
            $display("stage-R: %h gop=%h  valid=%b advance=%b chunk=%h index=%h",
                     INST, INST_gop, INST_valid, INST_advance,
                     code_chunk, code_index
            );
    end
//synthesis translate_on

endmodule
