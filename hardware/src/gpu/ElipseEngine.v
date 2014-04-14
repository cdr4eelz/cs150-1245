
module ElipseEngine #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input           clk, rst,

//Line control <=> CPU:
    output          EL_ready, //Can start issuing values/trigger
    input           EL_color_valid, //EL_color capture
    input   [ 31:0] EL_color,   //8-zeros, 3 x 8-bit R/G/B
    input           EL_x0_valid,//EL_point captured into x0
    input           EL_y0_valid,//  ... y0
    input           EL_x1_valid,//  ... x1
    input           EL_y1_valid,//  ... y1
    input   [  9:0] EL_point,   //Point data with each EL_[x0,y0,x1,y1]_valid
    input           EL_trigger, //Trigger drawing (EL_frame captured)
    input   [ 31:0] EL_frame,   //Frame-base (modulo 0x0040_0000)

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

// Manage line values (each is a register with RVA style "set")
                //Grabbed @clk & trigger  //MUXed to expose value @trigger
    reg  [ 5:0] framebits_r,              framebits;
    reg  [31:0] color_r,                  color;
    reg  [ 9:0] x0_r,y0_r, x1_r,y1_r,     x0,y0, x1,y1;
    always @(posedge clk) begin
        if (rst_r) begin //Internal reset (don't bog global rst unless needed)
            {framebits_r, color_r  } <= 0;
            {x0_r,y0_r,   x1_r,y1_r} <= 0;
        end else if (EL_ready) begin //Convenient "enable" line (redundant)
            {framebits_r, color_r  } <= {framebits, color}; //Feedback muxed vals
            {x0_r,y0_r,   x1_r,y1_r} <= {x0,y0,     x1,y1}; // since available.
        end
    end
    always @(*) begin //NOTE:Seems OK to lump into one always@* block!
        {framebits, color} = {framebits_r, color_r  };
        {x0,y0,     x1,y1} = {x0_r,y0_r,   x1_r,y1_r};
        if (EL_ready) begin //Preview/capture active inputs up until trigger
            if (EL_trigger)     framebits = EL_frame[27:22];
            if (EL_color_valid) color     = EL_color;
            if (EL_x0_valid)    x0        = EL_point;
            if (EL_y0_valid)    y0        = EL_point;
            if (EL_x1_valid)    x1        = EL_point;
            if (EL_y1_valid)    y1        = EL_point;
        end
    end


//Master-state Hotbit-index (as opposed to full Master-State register value)
    localparam
        MH_RSET     = 0, //Performing or coming out of reset          <=-._
        MH_IDLE     = 1, //Ready for initiation                            \
        MH_PRE4     = 2, //Prep/Normalize (examine raw x/y traits)          \
        MH_PRE3     = 3, //Prep/Normalize (examine raw x/y traits)           \
        MH_PRE2     = 4, //Prep/Normalize (translate/normalize x/y)           \
        MH_PRE1     = 5, //Prep/Normalize (finalize iteration params)         |
        MH_RUN1     = 6, //1st-half DDR-write; next-iteration work-ahead <-=\?/
        MH_RUN2     = 7; //2nd-half DDR-write; iteration finalize/advance ->_/
    localparam MH__LAST = MH_RUN2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET), MS_IDLE = (1<<MH_IDLE),
        MS_PRE4 = (1<<MH_PRE4), MS_PRE3 = (1<<MH_PRE3),
        MS_PRE2 = (1<<MH_PRE2), MS_PRE1 = (1<<MH_PRE1),
        MS_RUN1 = (1<<MH_RUN1), MS_RUN2 = (1<<MH_RUN2);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 9:0] a0,b0, a1,b1, a,b; //(a0,b0) & (a,b) redundant; kept for debug
    reg  MODE_incB, MODE_tran, MODE_flip;
    reg  [15:0] error, tempA,tempB, ADJ_negB,ADJ_posA;

//Key Live-Wires & Assigns
    wire [ 9:0] x,y;
    wire finishingSweep = (a >= a1);
    assign EL_ready = (cs_M[MH_IDLE]);
    assign {x,y} = (MODE_tran) ? {b,a} : {a,b};

//TODO:Segregate combinational (compare/adder/etc.) vs. sequential ("enables")
    reg  decrX, decrY;
    wire adv1, adv2;
    wire [15:0] difXu = ((decrX) ? x0 : x1) - ((decrX) ? x1 : x0); //Arrange >= 0 *in advance*
    wire [15:0] difYu = ((decrY) ? y0 : y1) - ((decrY) ? y1 : y0); //Arrange >= 0 *in advance*
    wire longerY = (difYu > difXu); //TODO:Consider algebraic re-grouping

//Master-State machine Next-States
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M) //TODO:Create MM_xyz "masks" & use Parallel-Case approach
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (EL_trigger) ns_M = MS_PRE4;
            MS_PRE4: ns_M = MS_PRE3;
            MS_PRE3: ns_M = MS_PRE2;
            MS_PRE2: ns_M = MS_PRE1;
            MS_PRE1: ns_M = MS_RUN1; //TODO:Check non-draw
            MS_RUN1: if (adv1) ns_M = MS_RUN2;
            MS_RUN2: if (adv2) ns_M = (finishingSweep) ? MS_RSET : MS_RUN1;
            default: ns_M = MS__DEAD;
        endcase
    end

//Synchronous transistions & data-path
    always @(posedge clk) begin
        if (rst_r) cs_M <= MS_RSET; else cs_M <= ns_M;

//TODO:Set registers to "don't care" when possible (allow re-use/optimizations)
        case (cs_M)
            MS_RSET: begin
                {a,b} <= 0; //Not much important about reset, better to not-care!
            end
            MS_IDLE: if (EL_trigger) begin
                //Modest comparator delay imposed on predecessor as "setup" time,
                {decrX,decrY} <= {(x1 < x0),(y1 < y0)}; // the dude must abide!
//TODO:Apply x/y CLIP or at least detect when needed & apply next
            end
        //From MS_PRE4 onward, use registered [x|y][0|1]_r directly
            MS_PRE4: begin
                {tempA,tempB} <= {difXu,difYu};
                MODE_tran <= (longerY); //Translate axes to step along LONGER one
                MODE_flip <= (longerY) ? decrY : decrX; //Stash for debug
            end
            MS_PRE3: begin // reG=>{INV=>}MUX=>Reg (TRIVIAL)
                case ({MODE_tran, MODE_flip}) //Flat-MUXIE (x,y)'s -=> (a,b)'s
                    2'b0_0: {a0,b0, a1,b1, MODE_incB} <= {x0_r,y0_r, x1_r,y1_r, !decrY};
                    2'b0_1: {a0,b0, a1,b1, MODE_incB} <= {x1_r,y1_r, x0_r,y0_r,  decrY};
                    2'b1_0: {a0,b0, a1,b1, MODE_incB} <= {y0_r,x0_r, y1_r,x1_r, !decrX};
                    2'b1_1: {a0,b0, a1,b1, MODE_incB} <= {y1_r,x1_r, y0_r,x0_r,  decrX};
                endcase //Case is fully covered
            end
            MS_PRE2: begin // [ [(reG=>mux)|*2]=>SUB | SUB ]=>Reg
                ADJ_negB  <= ((MODE_incB) ? b0 : b1) - ((MODE_incB) ? b1 : b0); //Arrange <= 0
                tempA     <= (a1 - a0); //Guaranteed >= 0
            end
            MS_PRE1: begin // reG=>[ADD | wire]=>Reg
                ADJ_posA  <= (tempA + ADJ_negB);
                error     <= (tempA >> 1);
                a         <= a0;
                b         <= b0;
            end
            MS_RUN1: if (adv1) begin
                tempA     <= error + ADJ_posA;
                tempB     <= error + ADJ_negB;
            end
            MS_RUN2: if (adv2) begin
                //a & b affect x & y (preserve until x & y made it to PixelRunner)
                a         <= (a+1); //up-counter w/enable
                b         <= (tempB[15]) ? ((MODE_incB)?(b+1):(b-1)) : b; //up/down w/enable
                error     <= (tempB[15]) ? tempA : tempB;
            end
        endcase

    end


//Write "run" of pixels via ScanLineRunner module
    assign SLR_valid        = cs_M[MH_RUN1],
            SLR_frame       = {4'h1, framebits[5:0], 22'b0},
            SLR_color_edge  = color_r,
            SLR_color_fill  = { color_r[31:24], //Left/Right 1-pixel
                                color_r[23:16] >> 1, //Darkened
                                color_r[15: 8] >> 1,
                                color_r[ 7: 0] },
            SLR_col_start   = x - 0,//2,
            SLR_col_finish  = x + 0,//2,
            SLR_row         = y;

    assign adv1   = SLR_ready, //Used iif MH_RUN1 implying SLR_valid
            adv2  = 1'b1;


//synthesis translate_off
    always @(posedge clk) begin
        if (EL_ready && EL_trigger) begin
            #1;
            $display("[=LINE=]: frame=%h color=%h (%0d,%0d,%0d)", framebits,
                     color, color[23:16], color[15:8], color[7:0]);
            $display("        : (%4d,%4d)=>(%4d,%4d)  (%h,%h)=>(%h,%h)",
                     x0,y0, x1,y1,  x0,y0, x1,y1);
        end
    end
//synthesis translate_on

endmodule

/** ALORGITHM CORE ("c" model code) **

void swelipse(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const a, uint16_t const b)
{
    uint16_t x = 0, y = b; //theta=90 @origin (offset pixels in 4way)
    uint32_t const AA = sqr32(a), BB = sqr32(b);
    uint32_t const AABB = mul32(AA,BB);

    //Helper values to pre-compute multiplied values then adjust with addition
    uint32_t AAy    = mul32(AA,y);
    uint32_t BBx    = mul32(BB,x);
    uint32_t BB2xp3 = (mul32(BB,x)<<1) + (BB<<1) + BB;
    uint32_t AA2y   = (mul32(AA,y)<<1);

    int32_t dd; //dd

    dd = BB - mul32(AA,b) + (AA>>2);
    swpixel_4way(fp,color, xc,yc, x,y);

    while ( (AAy-(AA>>1)) > (BBx+BB) ) {
        if (dd >= 0) {
            dd += (AA<<1) - AA2y; //mul32(AA,y<<1);
            y--; AAy -= AA; AA2y -= (AA<<1);
        }
        dd += BB2xp3; //mul32(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        swpixel_4way(fp,color, xc,yc, x,y);
    }
//return;
//printf("\\\\\\\n");
    //Transition at slope=1, whatever theta happens to be; Reverse x&y roles
    uint32_t BB2xp2 = BB2xp3 - BB; //mul32(BB,(x<<1)+2);
    dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
    while (y > 0) {
        if (dd < 0) {
            dd += BB2xp2; //mul32(BB,(x<<1)+2);
            x++; BB2xp2 += (BB<<1);
        }
        dd += (AA<<1)+AA - AA2y; //mul32(AA,y<<1);
        y--; AA2y -= (AA<<1);
        swpixel_4way(fp,color, xc,yc, x,y);
    }
} */