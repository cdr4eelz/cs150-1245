
module LineEngine #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter SCANLINERUNNER=0, LITTLEWORDIAN=1
)(
    input           clk, rst,

//Line control <=> GPU:
    output          LE_ready, //Can start issuing values/trigger
    input           LE_color_valid, //LE_color capture
    input   [ 31:0] LE_color,   //8-zeros, 3 x 8-bit R/G/B
    input           LE_x0_valid,//LE_point captured into x0
    input           LE_y0_valid,//  ... y0
    input           LE_x1_valid,//  ... x1
    input           LE_y1_valid,//  ... y1
    input   [  9:0] LE_point,   //Point data with each LE_[x0,y0,x1,y1]_valid
    input           LE_trigger, //Trigger drawing (LE_frame captured)
    input   [ 31:0] LE_frame,   //Frame-base (modulo 0x0040_0000)

//DDR FIFOs (write-only): [if !SCANLINERUNNER]
    input           caf_full,
    input           wdf_full,
    output          caf_wren,
    output  [ 27:0] caf_addr,
    output          wdf_wren,
    output  [127:0] wdf_data,
    output  [ 15:0] wdf_mask,

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

    // Implement Bresenham's line drawing algorithm here!

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
        end else if (LE_ready) begin //Convenient "enable" line (redundant)
            {framebits_r, color_r  } <= {framebits, color}; //Feedback muxed vals
            {x0_r,y0_r,   x1_r,y1_r} <= {x0,y0,     x1,y1}; // since available.
        end
    end
    always @(*) begin //NOTE:Seems OK to lump into one always@* block!
        {framebits, color} = {framebits_r, color_r  };
        {x0,y0,     x1,y1} = {x0_r,y0_r,   x1_r,y1_r};
        if (LE_ready) begin //Preview/capture active inputs up until trigger
            if (LE_trigger)     framebits = LE_frame[27:22];
            if (LE_color_valid) color     = LE_color;
            if (LE_x0_valid)    x0        = LE_point;
            if (LE_y0_valid)    y0        = LE_point;
            if (LE_x1_valid)    x1        = LE_point;
            if (LE_y1_valid)    y1        = LE_point;
        end
    end


/* Philosophy is to take a few preliminary cycles normalizing input points
**   and establishing parameters for the iteration.  This would allow a
**   potentially faster clock rate to be applied overall, resource sharing
**   such as adders/comparators with minimal cost of added latency.  Could
**   even consider multi-cycle delays for any exceptionally slow prep work.
*/

//Master-state Hotbit-index (as opposed to full Master-State register value)
    localparam
        MH_RSET     = 0, //Performing or coming out of reset       <=-.___
        MH_IDLE     = 1, //Ready for initiation                           \
        MH_PRE5     = 2, //Prep/Normalize (examine raw x/y traits)         \
        MH_PRE4     = 3, //Prep/Normalize (examine raw x/y traits)          \
        MH_PRE3     = 4, //Prep/Normalize (examine raw x/y traits)           \
        MH_PRE2     = 5, //Prep/Normalize (translate/normalize x/y)           \
        MH_PRE1     = 6, //Prep/Normalize (finalize iteration params)         |
        MH_RUN1     = 7, //1st-half DDR-write; next-iteration work-ahead <-=\?/
        MH_RUN2     = 8; //2nd-half DDR-write; iteration finalize/advance ->_/
    localparam MH__LAST = MH_RUN2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET), MS_IDLE = (1<<MH_IDLE),
        MS_PRE5 = (1<<MH_PRE5), MS_PRE4 = (1<<MH_PRE4),
        MS_PRE3 = (1<<MH_PRE3), MS_PRE2 = (1<<MH_PRE2),
        MS_PRE1 = (1<<MH_PRE1),
        MS_RUN1 = (1<<MH_RUN1), MS_RUN2 = (1<<MH_RUN2);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 9:0] a0,b0, a1,b1, a,b; //(a0,b0) & (a,b) redundant; kept for debug
    reg  MODE_incB, MODE_tran, MODE_flip;
    reg  [15:0] error, tempA,tempB, ADJ_negB,ADJ_posA;

//Key Live-Wires & Assigns
    wire [ 9:0] x,y;
    wire finishingSweep = (a >= a1);
    assign LE_ready = (cs_M[MH_IDLE]);
    assign {x,y} = (MODE_tran) ? {b,a} : {a,b};

//TODO:Segregate combinational (compare/adder/etc.) vs. sequential ("enables")
    reg  decrX, decrY;
    wire adv1, adv2;
    wire [15:0] difXu = ((decrX) ? x0_r : x1_r) - ((decrX) ? x1_r : x0_r); //Arrange >= 0 *in advance*
    wire [15:0] difYu = ((decrY) ? y0_r : y1_r) - ((decrY) ? y1_r : y0_r); //Arrange >= 0 *in advance*
    wire longerY = (difYu > difXu); //TODO:Consider algebraic re-grouping

//Master-State machine Next-States
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M) //TODO:Create MM_xyz "masks" & use Parallel-Case approach
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (LE_trigger) ns_M = MS_PRE5;
            MS_PRE5: ns_M = MS_PRE4;
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
            MS_IDLE: if (LE_trigger) begin
                //TODO:Apply x/y CLIP or at least detect when needed & apply next
            end
        //From MS_PRE5 onward, use registered [x|y][0|1]_r directly
            MS_PRE5: begin
                {decrX,decrY} <= {(x1_r < x0_r),(y1_r < y0_r)};
            end
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


generate if (SCANLINERUNNER) begin:_WITH_SLR_

//Write "run" of pixels instead via ScanLineRunner module
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

    assign caf_wren     = 1'b0,
            caf_addr    = 28'bx,
            wdf_wren    = 1'b0,
            wdf_data    = 128'bx,
            wdf_mask    = 16'bx;

end else begin:_NO_SLR_

    assign SLR_valid = 1'b0;

//Drive DDR lines to write 1 pixel at-a-time
    reg  [ 3:0] maskW;
    wire [31:0] cpu_addr = {4'h1, framebits[5:0], y[9:0], x[9:3], 5'b00}; //CPU "byte" address
    wire [ 2:0] offset_pixel  = (LITTLEWORDIAN) ? x[2:0] : ~x[2:0];

    assign caf_addr  = {3'b000, cpu_addr[27:3]}, //Turn into 31-bit "DoubleWord" or DDR-address
            wdf_mask = { {4{maskW[3]}}, {4{maskW[2]}}, {4{maskW[1]}}, {4{maskW[0]}} },
            wdf_data      = {4{color_r}}, //Replicate same color on all 4 pixels of both writes
            caf_wren     = (cs_M[MH_RUN1]),
            wdf_wren    = (cs_M[MH_RUN1] || cs_M[MH_RUN2]);
    assign adv1 = (!wdf_full && !caf_full),
            adv2 = (!wdf_full);

    always @(*) begin
        case ({cs_M[MH_RUN1],cs_M[MH_RUN2], offset_pixel})
            5'b10_000: maskW = 4'b0111; //NOTE: LITTLEWORDIAN
            5'b10_001: maskW = 4'b1011;
            5'b10_010: maskW = 4'b1101;
            5'b10_011: maskW = 4'b1110;
            5'b01_100: maskW = 4'b0111;
            5'b01_101: maskW = 4'b1011;
            5'b01_110: maskW = 4'b1101;
            5'b01_111: maskW = 4'b1110;
            default:   maskW = 4'b1111;
        endcase
    end

end endgenerate

//synthesis translate_off
/*
    initial $monitor("RT:%b/%b C/N:%b/%b (%0d,%0d)->(%0d,%0d)/(%0d,%0d) %h/%b (%h) W%b/%b",
                     rst,LE_trigger, cs_M,ns_M, a0,b0, a1,b1, x,y,
                     caf_addr, maskW, wdf_mask,
                     caf_wren, wdf_wren);
*/
    always @(posedge clk) begin
        if (LE_ready && LE_trigger) begin
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

// COMPLETE: UNSIGNED only, isolated PREP/ITER stages, identified PARALLEL blocks
void swline(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    int16_t const difXs = (x1 - x0);
    int16_t const difYs = (y1 - y0);
    BOOL const decrX = (difXs < 0), decrY = (difYs < 0);
    uint16_t const difXu = (decrX) ? -difXs : difXs;
    uint16_t const difYu = (decrY) ? -difYs : difYs;
    BOOL const tran = (difYu > difXu) ? 1 : 0;
    BOOL const flip = (tran) ? decrY : decrX;
    uint16_t a0, a1, b0, b1;
    if (tran) {
        if (flip) {
            a0 = y1; b0 = x1; //swap_u16(&x0, &y0) & swap_u16(&a0, &a1);
            a1 = y0; b1 = x0; //swap_u16(&x1, &y1) & swap_u16(&b0, &b1);
        } else {
            a0 = y0; b0 = x0; //swap_u16(&x0, &y0);
            a1 = y1; b1 = x1; //swap_u16(&x1, &y1);
        }
    } else {
        if (flip) {
            a0 = x1; b0 = y1; //swap_u16(&a0, &a1);
            a1 = x0; b1 = y0; //swap_u16(&b0, &b1);
        } else {
            a0 = x0; b0 = y0;
            a1 = x1; b1 = y1;
        }
    }
    BOOL const incB = (b1 > b0);
    uint32_t const offB = (incB) ? 1 : 0xFFFFFFFF; //B addend fake-signed (+/- 1)
    uint32_t const negB = (incB) ? (b0 - b1) : (b1 - b0); //Error addend fake-signed (arrange "<=" 0)
    uint32_t const errA = (a1 - a0); //Error addend; (guaranteed >= 0)
    uint32_t const posA = (errA + negB); //Error addend signed, net after errA/2 (guaranteed >= 0)
    uint32_t error = (errA >> 1); //error is s30.1 fixed-point signed (guaranteed >= 0)
    uint16_t a = a0, b = b0;
    while (a <= a1) {
        //FORK:iter-1
        uint32_t const nextA = a + 1;
        uint32_t const nextB = b + offB;
        uint32_t const errorA = error + posA;
        uint32_t const errorB = error + negB;
        uint16_t x = ((tran) ? b : a);
        uint16_t y = ((tran) ? a : b);
        swpixel(fp,color, x,y);
        //JOIN:iter-1
        //FORK:iter-2
        a     = nextA;
        b     = (errorB & 0x80000000) ? nextB  : b;
        error = (errorB & 0x80000000) ? errorA : errorB;
        //JOIN:iter-2
    }
} */
