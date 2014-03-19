
module LineEngine #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input           clk,
    input           rst,
//DDR FIFOs (write-only):
    input           af_full,
    input           wdf_full,
    output  [ 30:0] af_addr_din,
    output          af_wr_en,
    output  [127:0] wdf_din,
    output  [ 15:0] wdf_mask_din,
    output          wdf_wr_en,
//Line control <=> CPU:
    output          LE_ready, //Can start issuing values/trigger
    input           LE_color_valid, //LE_color capture
    input   [ 31:0] LE_color,   //8-zeros, 3 x 8-bit R/G/B
    input           LE_x0_valid,//LE_point captured into x0
    input           LE_y0_valid,//  ... y0
    input           LE_x1_valid,//  ... x1
    input           LE_y1_valid,//  ... y1
    input   [  9:0] LE_point,   //Point data with each LE_[x0,y0,x1,y1]_valid
    input           LE_trigger, //Trigger drawing (LE_frame captured)
    input   [ 31:0] LE_frame    //Frame-base (modulo 0x0040_0000)
);

    // Implement Bresenham's line drawing algorithm here!

// Manage line values (each is a register with RVA style "set")
    reg  [31:0] color;
    reg  [ 9:0] x0,y0, x1,y1;
    reg  [ 5:0] framebits;

    always @(posedge clk) begin
        if (LE_ready) begin //Capture active inputs if not running
            if (LE_color_valid) color <= LE_color;
            if (LE_x0_valid) x0 <= LE_point;
            if (LE_y0_valid) y0 <= LE_point;
            if (LE_x1_valid) x1 <= LE_point;
            if (LE_y1_valid) y1 <= LE_point;
            if (LE_trigger) framebits <= LE_frame[27:22];
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
        MH_RSET     = 0, //Performing or coming out of reset
        MH_IDLE     = 1, //Ready for initiation
        MH_PRE3     = 2, //Prep/Normalize (examine raw x/y traits)
        MH_PRE2     = 3, //Prep/Normalize (translate/normalize x/y)
        MH_PRE1     = 4, //Prep/Normalize (finalize iteration params)
        MH_RUN1     = 5, //1st-half DDR-write; next-iteration work-ahead
        MH_RUN2     = 6; //2nd-half DDR-write; iteration finalize/advance
    localparam MH__LAST = 6;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET), MS_IDLE = (1<<MH_IDLE),
        MS_PRE3 = (1<<MH_PRE3), MS_PRE2 = (1<<MH_PRE2), MS_PRE1 = (1<<MH_PRE1),
        MS_RUN1 = (1<<MH_RUN1), MS_RUN2 = (1<<MH_RUN2);

//Key State Registers
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  rst_r;
    reg  [ 9:0] y,x, b0,a0, b1,a1;

//Key Live-Wires & Assigns
    wire pastA = (a0 > a1);
    assign LE_ready = (cs_M[MH_IDLE]);

//Master-State machine Next-States
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M) //TODO:Create MM_xyz "masks" & use Parallel-Case approach
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (LE_trigger) ns_M = MS_PRE3;
            MS_PRE3: ns_M = MS_PRE2;
            MS_PRE2: ns_M = MS_PRE1;
            MS_PRE1: ns_M = MS_RUN1; //TODO:Check non-draw
            MS_RUN1: if (!wdf_full && !af_full) ns_M = MS_RUN2;
            MS_RUN2: if (!wdf_full) ns_M = (pastA) ? MS_RSET : MS_RUN1;
            default: ns_M = MS__DEAD;
        endcase
    end

reg  MODE_incY;
/*
    wire [15:0] errX = (x1 - x0); //Error addend; (assumed >= 0)
    wire [15:0] errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    wire [15:0] offY = (incY) ? 1 : 0xFFFFFFFF; //Y addend fake-signed (pos/"neg" one)
    wire [15:0] negY = (~errY + 1); //Error addend fake-signed (arrange "<=" 0)
    wire [15:0] posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)
*/

//Synchronous transistions & data-path
    always @(posedge clk) begin
        rst_r <= rst;
        if (rst) cs_M <= MS_RSET; else cs_M <= ns_M;
    end


    always @(posedge clk) begin
//TODO:These become "nextXYZ" signals instead (with don't cares)!
        if (LE_ready && LE_trigger) begin //Grab-ahead if simultaneous set & trigger
            a0 <= (LE_x0_valid) ? LE_point : x0;
            a1 <= (LE_x1_valid) ? LE_point : x1;
            b0 <= (LE_y0_valid) ? LE_point : y0;
            b1 <= (LE_y1_valid) ? LE_point : y1;
//$strobe("L:TRIG (%0d,%0d) (%0d,%0d)", a0,b0, a1,b1);
//TODO:Make new PREP stage for "steep" pre-calcs
        end else if (cs_M[MH_PRE3]) begin
            //TODO:Normalize to increasing a0 (swap a0/b0 & a1/b1)
            //TODO:Apply steep (swap x & y) simultaneous with steep (4 possibilities)
            {a0,a1} <= {a0,a1};
            {b0,b1} <= {b0,b1};
            MODE_incY <= (b1 > b0) ? 1'b1 : 1'b0;
//$strobe("L:PREP (%0d,%0d) (%0d,%0d)", a0,b0, a1,b1);
        end else if (cs_M[MH_RUN1] && !wdf_full && !af_full) begin
            a0 <= (a0+1);
            b0 <= (MODE_incY) ? (b0+1) : (b0-1);
//$strobe("L:INC (a0=%0d)", a0);
        end

        if (cs_M[MH_RSET]) begin
            {x,y} <= 0;
        end else if ((cs_M[MH_PRE3]) || (cs_M[MH_RUN2] && !wdf_full)) begin
            {x,y} <= {a0,b0};
//$strobe("L:ADV (x=%0d)", x);
        end
    end


//Drive DDR lines to write 1 pixel at-a-time
//TODO:Write "run" of pixels instead
    reg [3:0] maskW;
    wire [31:0] head_addr = {4'h1, framebits[5:0], y[9:0], x[9:3], 5'b00}; //"Byte" address
    assign af_addr_din = {6'b000000, head_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign af_wr_en  = (cs_M[MH_RUN1]);
    assign wdf_mask_din = { {4{maskW[3]}}, {4{maskW[2]}}, {4{maskW[1]}}, {4{maskW[0]}} };
    assign wdf_din = {4{color}}; //Replicate same color on all 4 pixels of both writes
    assign wdf_wr_en = (cs_M[MH_RUN1] || cs_M[MH_RUN2]);

    always @(*) begin
        case ({cs_M[MH_RUN1],cs_M[MH_RUN2], x[2:0]})
            5'b10_000: maskW = 4'b0111;
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


//synthesis translate_off
    initial $monitor("RT:%b/%b C/N:%b/%b (%0d,%0d)->(%0d,%0d)/(%0d,%0d) %h/%b (%h) W%b/%b",
                     rst,LE_trigger, cs_M,ns_M, a0,b0, a1,b1, x,y,
                     af_addr_din, maskW, wdf_mask_din,
                     af_wr_en, wdf_wr_en);
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

// SIMPLIFIED: STEEP & SWAP REMOVED
void line_UI32( const uint16_t x0, const uint16_t y0, const uint16_t x1, const uint16_t y1) {
    const char incY = (y1 > y0);
    const uint32_t errX = (x1 - x0); //Error addend; (assumed >= 0)
    const uint32_t errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    const uint32_t offY = (incY) ? 1 : 0xFFFFFFFF; //Y addend fake-signed (pos/"neg" one)
    const uint32_t negY = (~errY + 1); //Error addend fake-signed (arrange "<=" 0)
    const uint32_t posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)

    uint32_t error = (errX >> 1); //error is s30.1 fixed-point signed (guaranteed >= 0)
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        //FORK (parallel)
        const uint32_t errorA = error + negY;
        const uint32_t errorB = error + posX;
        const uint32_t nextX = x + 1;
        printf("%4d %4d\n", x, y);
        //JOIN
        //FORK (parallel)
        error = (errorA & 0x80000000) ? errorB : errorA;
        if (errorA & 0x80000000) y += offY;
        x = nextX;
        //JOIN
    }
}

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
    BOOL const spin = (difYu > difXu) ? 1 : 0;
    BOOL const flip = (spin) ? decrY : decrX;
    uint16_t a0, a1, b0, b1;
    if (spin) {
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
    //uint32_t const errB = (incB) ? (b1 - b0) : (b0 - b1); //Error subtracted portion (arrange >= 0)
    //negB = (~errB + 1);
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
        uint16_t x = ((spin) ? b : a);
        uint16_t y = ((spin) ? a : b);
        swpixel(fp,color, x,y);
        //JOIN:iter-1
        //FORK:iter-2
        a     = nextA;
        b     = (errorB & 0x80000000) ? nextB  : b;
        error = (errorB & 0x80000000) ? errorA : errorB;
        //JOIN:iter-2
    }
} */