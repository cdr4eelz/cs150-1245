`timescale 1ns/1ps

module RectangleEngine #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600
)(
    input           clk, rst,

//Rectangle control <=> GPU:
//TODO: Specify all controlling signals at one time during trigger (from GP)
    output          RE_ready, //Can start issuing values/trigger
    input           RE_color_valid, //RE_color capture into "color" (edge color)
    input           RE_backc_valid, //RE_color capture into "backc" (background/fill)
    input   [ 31:0] RE_color,   //4-zeros, 4-bits special, 3 x 8-bit (4+4+R/G/B)
    input           RE_xl_valid,//RE_point captured as LEFT, and/or...
    input           RE_yt_valid,//  ... TOP
    input           RE_xr_valid, //  ... RIGHT
    input           RE_yb_valid, //  ... BOTTOM
    input   [  9:0] RE_point,   //Point data with each RE_[xl,yt,xr,yb]_valid
    input           RE_trigger, //Trigger drawing (RE_frame captured)
    input   [ 31:0] RE_frame,   //Frame-base (modulo 0x0040_0000)

//SLR control (write-only):
    input           SLR_ready,
    output          SLR_valid,
    output  [ 31:0] SLR_frame,
    output  [ 31:0] SLR_color_edge,
    output  [ 31:0] SLR_color_fill,
    output  [  9:0] SLR_row,
    output  [  9:0] SLR_col_start,
    output  [  9:0] SLR_col_finish
);

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, <rst>_r, unless really must sync-up release!
    end

// Manage rectangle values (each is a register with RVA style "set")
                //Grabbed @clk & trigger  //MUXed to expose value @trigger
    reg  [ 5:0] framebits_r,              framebits;
    reg  [31:0] color_r,                  color;
    reg  [31:0] backc_r,                  backc;
    reg  [ 9:0] xl_r,yt_r, xr_r,yb_r,     xl,yt, xr,yb;

    always @(posedge clk) begin
        if (rst_r) begin //Internal reset (don't bog global rst unless needed)
            {framebits_r, color_r, backc_r} <= 0;
            {xl_r,yt_r, xr_r,yb_r} <= 0;
        end else if (RE_ready) begin
//$display("/// RE_ready: Capture new value ///");
            //TODO: Eliminate strange approach between registered and non-registered values!
            {framebits_r, color_r, backc_r} <= {framebits, color, backc};
            {xl_r,xr_r, yt_r,yb_r} <= {xl,xr, yt,yb};
        end
    end

    always @(*) begin //NOTE:Seems OK to lump into one always@* block!
        framebits = framebits_r;
        {color, backc} = {color_r, backc_r};
        {xl,yt, xr,yb} = {xl_r,yt_r, xr_r,yb_r};
        if (RE_ready) begin //Preview/capture active inputs up until trigger
            if (RE_trigger)     framebits = RE_frame[27:22];
            if (RE_color_valid) color     = RE_color;
            if (RE_backc_valid) backc     = RE_color;
            if (RE_xl_valid)    xl        = RE_point;
            if (RE_yt_valid)    yt        = RE_point;
            if (RE_xr_valid)    xr        = RE_point;
            if (RE_yb_valid)    yb        = RE_point;
        end
    end


//Master-state Hotbit-index (as opposed to full Master-State register value)
    localparam
        MH_RSET     = 0,  //Performing or coming out of reset
        MH_IDLE     = 1,  //Ready for initiation
        MH_DRAW     = 2;  //...
    localparam MH__LAST = MH_DRAW;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET),
        MS_IDLE = (1<<MH_IDLE),
        MS_DRAW = (1<<MH_DRAW);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;

//Iteration adjusted values
    reg  [ 9:0] yy, yb_saved;
    wire lastY = (yy >= yb_saved);

//Key Live-Wires & Assigns
    wire advSLR;
    wire T_START = (RE_ready && RE_trigger);
    wire T_DONE_FULL = advSLR && lastY;
    assign RE_ready = (cs_M[MH_IDLE]);

//Synchronous transistions & data-path
    always @(posedge clk) begin
        if (rst_r) cs_M <= MS_RSET; else cs_M <= ns_M;

        if (cs_M[MH_DRAW]) begin
            if (advSLR) yy <= (yy + 1);
        end else if (T_START) begin
            {yy,yb_saved} <= (yt <= yb) ? {yt,yb} : {yb,yt};
        end
    end


//Next-State
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            MS_RSET: ns_M = MS_IDLE; //Gives 1-cycle in MS_RSET after !rst_r
            MS_IDLE: if (T_START) ns_M = MS_DRAW;
            MS_DRAW: if (T_DONE_FULL) ns_M = MS_RSET;
            default: ns_M = MS__DEAD; //Default for untrapped
        endcase
    end


//Write "run" of pixels via ScanLineRunner module
    assign SLR_valid        = cs_M[MH_DRAW],
            SLR_frame       = {4'h1, framebits[5:0], 22'b0},
            SLR_color_edge  = color,
            SLR_color_fill  = ((yy == yt) || lastY) ? (32'hFF000000 | color) : backc,
            SLR_col_start   = xl,
            SLR_col_finish  = xr,
            SLR_row         = yy;

    assign advSLR = SLR_ready && SLR_valid;


//synthesis translate_off
    always @(posedge clk) begin
        if (T_START) begin
            //#1; // Hack to make sure the *_r values are pre-captured (notably framebits)
            $display("[=RECT=]: frame=%h color=0x%h %0d(%0d,%0d,%0d)", framebits,
                     color, color[31:24], color[23:16], color[15:8], color[7:0]);
            $display("        : backc=0x%h %0d(%0d,%0d,%0d)", backc,
                     backc[31:24], backc[23:16], backc[15:8], backc[7:0]);
            $display("        : (%4d,%4d)=>(%4d,%4d)  (%3h,%3h)=>(%3h,%3h)",
                     xl,yt, xr,yb,  xl,yt, xr,yb);
        end
    end
//synthesis translate_on

endmodule
