
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


/* Philosophy is to take preliminary cycle(s) normalizing the input points
**   and establishing characteristics such as "steep".  This would allow a
**   potentially faster clock rate to be applied to the more repetitive but
**   simpler heart of the iteration.  Multi-cycle delays could even come in
**   to play for preparatory or exceptional value handling.
*/

//Master-States:
    localparam [2:0]
        MS_DEAD     = 0, //Initial or fault (requires explicit reset)
        MS_RSET     = 1, //Performing or coming out of reset
        MS_IDLE     = 2, //Ready for initiation
        MS_PREP     = 3, //Prepare/Normalize values for iteration
        MS_PWR1     = 4, //First half of pixel DDR write
        MS_PWR2     = 5; //Second half
    localparam MS__LAST = 5;

//Key State Registers
    reg  [ 2:0] ns_M, cs_M = MS_DEAD;
    reg  [ 9:0] y,x, b,a, bLast,aLast;
    reg  rst_r;

    wire pastA = (a > aLast);
    //TODO:Watchout for locking up when no pixels to draw!

//Triggers for state transitions & Mealy outputs (usually 1-cycle duration)
    //   T_DEAD   = INITIAL upon FPGA config
    wire T_RESET  = (rst);
    wire T_READY  = (!rst_r);
    wire T_START  = (LE_ready && LE_trigger);
    wire T_NORML  = (cs_M==MS_PREP); //Normalized iteration values are ready
    wire T_WRIT1  = (cs_M==MS_PWR1 && !wdf_full && !af_full); //DDR took first-half
    wire T_WRIT2  = (cs_M==MS_PWR2 && !wdf_full); //DDR took second-half

    assign LE_ready = (cs_M==MS_IDLE);

    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M)
            MS_DEAD: if (T_RESET) ns_M = MS_RSET; //Redundant with machine reset
            MS_RSET: if (T_READY) ns_M = MS_IDLE;
            MS_IDLE: if (LE_trigger) ns_M = MS_PREP;
            MS_PREP: ns_M = MS_PWR1; //TODO:Check non-draw
            MS_PWR1: if (!wdf_full && !af_full) ns_M = MS_PWR2;
            MS_PWR2: if (!wdf_full) ns_M = (pastA) ? MS_RSET : MS_PWR1;
            default: ns_M = MS_DEAD;
        endcase
    end
    always @(posedge clk) begin
        rst_r <= rst;

        if (T_RESET) begin
            cs_M <= MS_RSET;
        end else begin
            cs_M <= ns_M;
        end

//TODO:These become "nextXYZ" signals instead (with don't cares)!
        if ((LE_ready && LE_trigger) || (cs_M==MS_PREP)) begin
            {a,aLast} <= {x0,x1};
            {b,bLast} <= {y0,y1};
//$strobe("L:PREP (%0d,%0d) (%0d,%0d)", a,b, aLast,bLast);
        end else if (T_WRIT1) begin
            a <= (cs_M==MS_PREP) ? x0 : (a + 1);
//$strobe("L:INC (a=%0d)", a);
        end

        if (cs_M==MS_RSET) begin
            {x,y} <= 0;
        end else if ((cs_M==MS_PREP) || T_WRIT2) begin
            {x,y} <= (cs_M==MS_PREP) ? {x0,y0} : {a,b};
//$strobe("L:ADV (x=%0d)", x);
        end
    end


//Drive DDR lines to write 1 pixel at a time
//TODO:Write a "run" of pixels instead
    reg [3:0] maskW;
    wire [31:0] head_addr = {4'h1, framebits[5:0], y[9:0], x[9:0], 2'b00}; //"Byte" address
    assign af_addr_din = {6'b000000, head_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign af_wr_en  = (cs_M == MS_PWR1);
    assign wdf_mask_din = { {4{maskW[3]}}, {4{maskW[2]}}, {4{maskW[1]}}, {4{maskW[0]}} };
    assign wdf_din = {4{color}}; //Replicate same color on all 4 pixels of both writes
    assign wdf_wr_en = ((cs_M == MS_PWR1) || (cs_M == MS_PWR2));

    always @(*) begin
        case ({(cs_M==MS_PWR1),(cs_M==MS_PWR2),x[2:0]})
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
    initial $monitor("RT:%b/%b CN:%0d/%0d (%0d,%0d)/(%0d,%0d) %h/%b (%h) W%b/%b",
                     T_RESET,LE_trigger, cs_M,ns_M, a,b, x,y,
                     af_addr_din, maskW, wdf_mask_din,
                     af_wr_en, wdf_wr_en);
    always @(posedge clk) begin
        if (T_START) begin
            #1;
            $display("[=LINE=]: frame=%h color=%h (%0d,%0d,%0d)", framebits,
                     color, color[23:16], color[15:8], color[7:0]);
            $display("        : (%4d,%4d)=>(%4d,%4d)  (%h,%h)=>(%h,%h)",
                     x0,y0, x1,y1,  x0,y0, x1,y1);
        end
    end
//synthesis translate_on

endmodule

/** ALORGITHM CORE (STEEP & SWAP REMOVED) **
void line_UI32(
    const uint16_t x0, const uint16_t y0,
    const uint16_t x1, const uint16_t y1)
{
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
*/