`timescale 1 ns/1 ps

module ElipseEngine #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600
)(
    input           clk, rst,

//Elipse control <=> GPU:
    output          EL_ready, //Can start issuing values/trigger
    input           EL_color_valid, //EL_color capture
    input   [ 31:0] EL_color,   //8-zeros, 3 x 8-bit R/G/B
    input           EL_xc_valid,//EL_point captured into xc, and/or...
    input           EL_yc_valid,//  ... yc
    input           EL_a_valid, //  ... a
    input           EL_b_valid, //  ... b
    input   [  9:0] EL_point,   //Point data with each EL_[xc,yc,a,b]_valid
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

// Manage elipse values (each is a register with RVA style "set")
                //Grabbed @clk & trigger  //MUXed to expose value @trigger
    reg  [ 5:0] framebits_r,              framebits;
    reg  [31:0] color_r,                  color;
    reg  [ 9:0] xc_r,yc_r, a_r,b_r,       xc,yc, a,b;
    always @(posedge clk) begin
        if (rst_r) begin //Internal reset (don't bog global rst unless needed)
            {framebits_r, color_r} <= 0;
            {xc_r,yc_r,   a_r,b_r} <= 0;
        end else if (EL_ready) begin
            {framebits_r, color_r} <= {framebits, color}; //Feedback muxed vals
            {xc_r,yc_r,   a_r,b_r} <= {xc,yc,     a,b};  // since available.
        end
    end
    always @(*) begin //NOTE:Seems OK to lump into one always@* block!
        {framebits, color} = {framebits_r, color_r  };
        {xc,yc,     a,b}   = {xc_r,yc_r,   a_r,b_r};
        if (EL_ready) begin //Preview/capture active inputs up until trigger
            if (EL_trigger)     framebits = EL_frame[27:22];
            if (EL_color_valid) color     = EL_color;
            if (EL_xc_valid)    xc        = EL_point;
            if (EL_yc_valid)    yc        = EL_point;
            if (EL_a_valid)     a         = EL_point;
            if (EL_b_valid)     b         = EL_point;
        end
    end


//Master-state Hotbit-index (as opposed to full Master-State register value)
    localparam
        MH_RSET     = 0,  //Performing or coming out of reset
        MH_IDLE     = 1,  //Ready for initiation
        MH_PRa1     = 2,  //Prep/Normalize
        MH_PRa2     = 3,  //Prep/Normalize
        MH_PRa3     = 4,  //Prep/Normalize
        MH_SLa1     = 5,  //top-half SLR-write; next-iteration work-ahead
        MH_SLa2     = 6,  //bot-half SLR-write; iteration finalize/advance
        MH_PRb1     = 7,  //Prep for "B"
        MH_PRb2     = 8,  //Prep for "B"
        MH_PRb3     = 9,  //Prep for "B"
        MH_LLb1     = 10, //Adjust vals during loop
        MH_SLb1     = 11, //top-half SLR-write
        MH_SLb2     = 12; //bot-half SLR-write; iteration/done
    localparam MH__LAST = MH_SLb2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET), MS_IDLE = (1<<MH_IDLE),
        MS_PRa1 = (1<<MH_PRa1), MS_PRa2 = (1<<MH_PRa2), MS_PRa3 = (1<<MH_PRa3),
        MS_SLa1 = (1<<MH_SLa1), MS_SLa2 = (1<<MH_SLa2),
        MS_PRb1 = (1<<MH_PRb1), MS_PRb2 = (1<<MH_PRb2), MS_PRb3 = (1<<MH_PRb3),
        MS_LLb1 = (1<<MH_LLb1), MS_SLb1 = (1<<MH_SLb1), MS_SLb2 = (1<<MH_SLb2);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 9:0] x, y, xy_next; // xy_next shared between phase A & B
    reg  [31:0] AA, BB, AABB; // These stay constant
    reg  signed [31:0] dd, dd_next, stopper; //signed; like "error" in line algorithm

//Iteration adjusted values
    reg  [31:0] CountA, CountB; // For debug and/or termination of runaway loops
    reg  [31:0] AAy, AAy_next, BBx, BB2xp3;
    reg  [31:0] BB2xp2;             //Phase B (== BB2xp3 - BB)
    reg  [31:0] temp_XX, temp_YM1YM1; //Intermediary values for Phase B
    reg  [31:0] temp_BBTX, temp_AAYZ; //Intermediary values for Phase B
    //reg  [31:0] AA2y, AA2y_next;
    wire signed [31:0] prep_dd_B = temp_BBTX + (BB>>2) + temp_AAYZ - AABB;


//Key Live-Wires & Assigns
    wire advSLR, continueA, continueB;
    wire [ 9:0] xL,xR, yT,yB;

//Synchronous transistions & data-path
    always @(posedge clk) begin
        if (rst_r) cs_M <= MS_RSET; else cs_M <= ns_M;

        case (cs_M)
            MS_RSET: begin
                {x,y} <= 0; //Not much important about reset, better to not-care!
            end
            MS_IDLE: if (EL_trigger) begin
                x       <= 0;               //Start at theta=90 with
                y       <= b;               //  (xc,yc) translated to (0,0)
                BBx     <= 0; //BB * x;     //(x==0)
                CountA <= 1; CountB <= 0; //The "A" phase ALWAYS at least 1
            end
        //From MS_PRa1 onward, use registered parameters directly "_r"
            MS_PRa1: begin
                AA      <= a_r * a_r;
                BB      <= b_r * b_r;
            end
            MS_PRa2: begin
                AABB    <= AA * BB;
                AAy     <= AA * b_r; //(y==b)
                BB2xp3  <= (BB<<1) + BB;    //(x==0)
                dd      <= BB + (AA>>2); //PARTIAL
                //AA2y    <= (AA * y)<<1; //(mul32(AA,y)<<1);
                stopper <= (AA>>1) + BB;    //end of first loop
            end
            MS_PRa3: begin
                dd      <= dd - AAy; //(y==b) and AAy==AAB
$display("%d ELIPSE-TB: [CONST] AA=%0d BB=%0d AABB=%0d stopper=%0d",
        $time, AA, BB, AABB, stopper);
            end
            MS_SLa1: if (advSLR) begin
$display("%8d ELIPSE-TB: CountA=%0d dd=%0d AAy=%0d BBx=%0d",
        $time, CountA, dd, AAy, BBx);
$display("%8d          : x=%0d y=%0d BB2xp3=%0d",
        $time, x, y, BB2xp3);
                if (dd >= 0) begin
                    //dd += (AA<<1) - (AAy<<1); //mul32(AA,y<<1);
                    dd_next <= dd + (AA<<1) - (AAy<<1); //mul32(AA,y<<1)???
                    //dd_next <= dd + (AA<<1) - AA2y; //mul32(AA,y<<1)???
                    xy_next <= y - 1;
                    AAy_next <= AAy - AA;
                    //AA2y_next <= AA2y - (AA<<1);
                end else begin
                    dd_next <= dd;
                    xy_next <= y;
                    AAy_next <= AAy;
                    //AA2y_next <= AA2y;                    
                end
            end
            MS_SLa2: if (advSLR) begin
                if (continueA) begin
                    CountA <= CountA + 1; //Count each loop around
                    dd <= dd_next + BB2xp3; //mul32(BB,(x<<1)+3)
                    y <= xy_next;
                    AAy <= AAy_next;
                    //AA2y <= AA2y_next;
                    x <= x + 1;
                    BBx <= BBx + BB;
                    BB2xp3 <= BB2xp3 + (BB<<1);
                end
            end
            MS_PRb1: begin
$display("%8d    --- LAST CountA=%0d",
        $time, CountA);
$display("/// NEXT LOOP ///");
                //PARTIAL: dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
                temp_XX <= x * x;
                temp_YM1YM1 <= (y-1) * (y-1);
            end
            MS_PRb2: begin
$display("%8d ELIPSE-PREP1: temp_XX=%0d temp_YM1YM1=%0d",
        $time, temp_XX, temp_YM1YM1);
                temp_BBTX <= BB * (temp_XX+x);
                temp_AAYZ <= AA * temp_YM1YM1;
            end
            MS_PRb3: begin
$display("%8d ELIPSE-PREP2: temp_BBTX=%0d temp_AAYZ=%0d",
        $time, temp_BBTX, temp_AAYZ);
                BB2xp2 <= BB2xp3 - BB; //mul32(BB,(x<<1)+2);
                dd <= prep_dd_B; //temp_BBTX + (BB>>2) + temp_AAYZ - AABB;
$display("%8d ELIPSE-PREP3: prep_dd_B=%0d BB2xp2=%0d",
        $time, prep_dd_B, BB2xp3 - BB); //Show "future" value since happens simultaneously
            end
            MS_LLb1: begin
                CountB <= CountB + 1;
                if (dd < 0) begin
                    x <= x+1; // x++
                    BB2xp2 <= BB2xp2 + (BB<<1); //BB2xp2 += (BB<<1);
                end
                //dd += (AA<<1)+AA - (AAy<<1); //mul32(AA,y<<1);
                dd <= dd + ((dd < 0)?BB2xp2:0) + (AA<<1)+AA - (AAy<<1);
                y <= y - 1; //y--;
                AAy <= AAy - AA; //AAy -= AA; //AA2y -= (AA<<1);
            end
            MS_SLb1: if (advSLR) begin
$display("%8d ELIPSE-TB: CountB=%0d dd=%0d AAy=%0d BB2xp2=%0d",
        $time, CountB, dd, AAy, BB2xp2);
$display("%8d          : x=%0d y=%0d",
        $time, x, y);
            end
            MS_SLb2: if (advSLR) begin
                if (!continueB) begin
#1 $display("%8d    --- LAST CountA=%0d CountB=%0d",
        $time, CountA, CountB);                    
                end
            end
        endcase

    end

/*
*** FIRST LOOP "A" ***
    while ((AAy-BBx) > stopper) { // (AAy-(AA>>1)) > (BBx+BB)
        if (dd >= 0) {
            dd += (AA<<1) - (AAy<<1); //mul32(AA,y<<1);
            y--; AAy -= AA; //AA2y -= (AA<<1);
        }
        dd += BB2xp3; //mul32(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
*** SECOND LOOP "B" ***
    uint32_t BB2xp2 = BB2xp3 - BB; //mul32(BB,(x<<1)+2);
    dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
    while (y > 0) {
        if (dd < 0) {
            dd += BB2xp2; //mul32(BB,(x<<1)+2);
            x++; BB2xp2 += (BB<<1);
        }
        dd += (AA<<1)+AA - (AAy<<1); //mul32(AA,y<<1);
        y--; AAy -= AA; //AA2y -= (AA<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
*/

    assign EL_ready = (cs_M[MH_IDLE]);
    assign xL = (xc-x);
    assign xR = (xc+x);
    assign yT = (yc-y);
    assign yB = (yc+y);
    assign continueA = (y > 0) && (x <= a) && (AAy - BBx) > stopper; //Slope == -1;
            //((AAy-BBx) > stopper) // (AAy-(AA>>1)) > (BBx+BB) //BBphaa
    assign continueB = (y > 0);

//Next-State
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (EL_trigger) ns_M = MS_PRa1;
            MS_PRa1: ns_M = MS_PRa2;
            MS_PRa2: ns_M = MS_PRa3;
            MS_PRa3: ns_M = MS_SLa1;
            MS_SLa1: if (advSLR) ns_M = MS_SLa2;
            MS_SLa2: if (advSLR) ns_M = (continueA) ? MS_SLa1 : MS_PRb1;
            MS_PRb1: ns_M = MS_PRb2;
            MS_PRb2: ns_M = MS_PRb3;
            MS_PRb3: ns_M = (continueB) ? MS_LLb1 : MS_IDLE;
            MS_LLb1: ns_M = MS_SLb1;
            MS_SLb1: if (advSLR) ns_M = MS_SLb2;
            MS_SLb2: if (advSLR) ns_M = (continueB) ? MS_LLb1 : MS_IDLE;
            default: ns_M = MS__DEAD;
        endcase
    end


//Write "run" of pixels via ScanLineRunner module
    assign SLR_valid        = (cs_M[MH_SLa1] || cs_M[MH_SLa2] ||
                               cs_M[MH_SLb1] || cs_M[MH_SLb2]),
            SLR_frame       = {4'h1, framebits[5:0], 22'b0},
            SLR_color_edge  = color_r,
            SLR_color_fill  = { color_r[31:24], //Left/Right 1-pixel
                                color_r[23:16] >> 1, //Darkened
                                color_r[15: 8] >> 1,
                                color_r[ 7: 0] },
            SLR_col_start   = xL,
            SLR_col_finish  = xR,
            SLR_row         = (cs_M[MH_SLa1] || cs_M[MH_SLb1]) ? yT : yB;

    assign advSLR = SLR_ready && SLR_valid; //Used iif MH_SLax implying SLR_valid


//synthesis translate_off
    always @(posedge clk) begin
        if (EL_ready && EL_trigger) begin
            #1;
            $display("[=ELIP=]: frame=%h color=%h %0d(%0d,%0d,%0d)", framebits,
                     color, color[31:24], color[23:16], color[15:8], color[7:0]);
            $display("        : (%4d,%4d)=>(%4d,%4d)  (%h,%h)=>(%h,%h)",
                     xc,yc, a,b,  xc,yc, a,b);
        end
    end
//synthesis translate_on

endmodule

/** ALORGITHM CORE ("c" model code) **

void swelip(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const a, uint16_t const b)
{
    uint16_t x = 0, y = b; //theta=90 @origin (offset pixels in 4way)
    uint32_t const AA = sqr32(a), BB = sqr32(b);
    uint32_t const AABB = mul32(AA,BB);

    //Helper values to pre-compute multiplied values then adjust with addition
    uint32_t AAy    = mul32(AA,y);
    uint32_t BBx    = 0; //(x==0): mul32(BB,x);
    uint32_t BB2xp3 = (BB<<1) + BB; //(x==0), //(mul32(BB,x)<<1) +
    //uint32_t AA2y   = (AAy<<1); //(mul32(AA,y)<<1);

    int32_t stopper = (AA>>1)+BB;
    int32_t dd      = BB - mul32(AA,b) + (AA>>2);

    swpixl_4way(fp,color, xc,yc, x,y);
    while ((AAy-BBx) > stopper) { // (AAy-(AA>>1)) > (BBx+BB)
        if (dd >= 0) {
            dd += (AA<<1) - (AAy<<1); //mul32(AA,y<<1);
            y--; AAy -= AA; //AA2y -= (AA<<1);
        }
        dd += BB2xp3; //mul32(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
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
        dd += (AA<<1)+AA - (AAy<<1); //mul32(AA,y<<1);
        y--; AAy -= AA; //AA2y -= (AA<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
} */
