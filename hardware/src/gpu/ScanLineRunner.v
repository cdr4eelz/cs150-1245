module ScanLineRunner #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input           clk,
    input           rst, //Synchronized internally
//DDR FIFOs (write-only):
    input           af_full,
    input           wdf_full,
    output          af_wr_en,
    output  [ 30:0] af_addr_din,
    output          wdf_wr_en,
    output  [127:0] wdf_din,
    output  [ 15:0] wdf_mask_din,
//ScanRun control <=> Engine/CPU:
    output          SLR_ready,
    input           SLR_valid,
    input   [ 31:0] SLR_frame,
    input   [ 31:0] SLR_color_edge,
    input   [ 31:0] SLR_color_fill,
    input   [  9:0] SLR_row,
    input   [  9:0] SLR_col_start,
    input   [  9:0] SLR_col_finish
);

    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, rst_r, unless really must sync-up release!
    end

    localparam
        MH_RSET     = 0, //Performing or coming out of reset     <=-._
        MH_IDLE     = 1, //Ready for initiation                       \
        MH_DDR1     = 2, //1st-half DDR-write     <----------------=\?/
        MH_DDR2     = 3; //2nd-half DDR-write; or done     -------->_/
    localparam MH__LAST = MH_DDR2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET),  MS_IDLE = (1<<MH_IDLE),
        MS_DDR1 = (1<<MH_DDR1),  MS_DDR2 = (1<<MH_DDR2);

//Drive DDR lines to write a "run" (series) of pixels
    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 3:0] maskW;
    reg  [ 9:0] y;
//  reg  [ 9:0] x, x_finish; //Old "stride 1" version
    reg  [ 6:0] X8, X8_finish;
    reg  isFIRST; //Manipulate reg rather than using comparators

    wire [ 9:0] x = {X8[6:0], 3'b000}; //Truncate to first pixel of chunk
    wire [ 5:0] framebits = SLR_frame[27:22];
    wire [31:0] cpu_addr = {4'h1, framebits[5:0], y[9:0], x[9:3], 5'b00}; //CPU "byte" address
    wire isLAST = (X8 >= X8_finish); //(x >= x_finish)
    wire wdr_advance1 = (!wdf_full && !af_full);
    wire wdr_advance2 = (!wdf_full);

    assign SLR_ready = (cs_M[MH_IDLE]);

//Master-State machine Next-States
    always @(*) begin
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M) //TODO:Create MM_xyz "masks" & use Parallel-Case approach
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (SLR_valid) ns_M = MS_DDR1; //We know we are ready since MS_IDLE
            MS_DDR1: if (wdr_advance1) ns_M = MS_DDR2;
            MS_DDR2: if (wdr_advance2) ns_M = (isLAST) ? MS_RSET : MS_DDR1;
            default: ns_M = MS__DEAD;
        endcase
    end
    always @(posedge clk) begin
        if (rst) cs_M <= MS_RSET; else cs_M <= ns_M;

        case (cs_M)
            MS_RSET: begin
                {y,X8,X8_finish,isFIRST} <= 'bx;
            end
            MS_IDLE: if (SLR_valid) begin
                y         <= SLR_row;
                X8        <= SLR_col_start[9:3];  //Round to a chunk of 8 pixels
                X8_finish <= SLR_col_finish[9:3]; //  so stride matches DDR width
                isFIRST   <= 1'b1;
            end
            MS_DDR1: begin
                //NADA
            end
            MS_DDR2: if (wdr_advance2) begin
                X8 <= (X8+1);
                isFIRST <= 1'b0;
            end
        endcase
    end


    assign af_addr_din  = {6'b000000, cpu_addr[27:3]}; //Turn into 31-bit "DoubleWord" or DDR-address
    assign af_wr_en     = (cs_M[MH_DDR1]);
    assign wdf_wr_en    = (cs_M[MH_DDR1] || cs_M[MH_DDR2]);
    assign wdf_mask_din = { {4{maskW[3]}}, {4{maskW[2]}}, {4{maskW[1]}}, {4{maskW[0]}} };
    assign wdf_din      = {4{SLR_color_fill}};

    always @(*) begin
        maskW = 4'b0000; //Temporarily write ALL pixels!
        case ({cs_M[MH_DDR1],cs_M[MH_DDR2], isFIRST, isLAST})
            4'b10_00: begin
                     maskW = 4'b0111;
            end
            4'b01_01: begin
                     maskW = 4'b1110;
            end
            default:   maskW = 4'b0000;
        endcase
    end

/*  OLD VERSION which swept each "x" individually
    always @(*) begin
        case ({cs_M[MH_DDR1],cs_M[MH_DDR2], x[2:0]})
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
*/

endmodule
