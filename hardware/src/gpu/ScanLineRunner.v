
`ifndef MACROSAFE
`define MACROSAFE
`endif // required to get this to compile...
`include "../base_util/const.vh"

module ScanLineRunner #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1,  //Order of 32-bit WORDS within each 256-bit block
    parameter SLR_COUNT=1       //Arbitrate multiple SLRs
)(
    input  wire         clk, rst,

//DDR FIFOs (write-only):
    input  wire         caf_full,
    input  wire         wdf_full,
    output wire         caf_wren,
    output wire[ 27:0]  caf_addr,
    output wire         wdf_wren,
    output wire[127:0]  wdf_data,
    output wire[ 15:0]  wdf_mask,

//ScanRun control(s) <=> Engine/GPU (concatenated buses):
    output wire[(SLR_COUNT)-1:0]    SLRs_ready,
    input  wire[(SLR_COUNT)-1:0]    SLRs_valid,
    input  wire[(SLR_COUNT*32)-1:0] SLRs_frame,
    input  wire[(SLR_COUNT*32)-1:0] SLRs_color_edge,
    input  wire[(SLR_COUNT*32)-1:0] SLRs_color_fill,
    input  wire[(SLR_COUNT*10)-1:0] SLRs_row,
    input  wire[(SLR_COUNT*10)-1:0] SLRs_col_start,
    input  wire[(SLR_COUNT*10)-1:0] SLRs_col_finish
);

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg  rst_r; //Detect & apply & release synchronously to our clock
    always @(posedge clk) begin
        rst_r <= rst; //Internal reset, <rst>_r, unless really must sync-up release!
    end

//Simple SLR Arbitrator
    wire SLR_MASTER_ready, SLR_switch;
    reg  [`log2(SLR_COUNT-1):0] live_SLR=0, next_SLR;
    reg  [(SLR_COUNT)-1:0] ready_SLRs;

    assign SLRs_ready = ready_SLRs;
    assign SLR_switch = SLR_MASTER_ready & !SLRs_valid[live_SLR];

    //Drive readyness only to one SLR
    always @(live_SLR or SLR_MASTER_ready) begin:_SLR_RDY_
        ready_SLRs = 0;
        ready_SLRs[live_SLR] = SLR_MASTER_ready;
    end

    //Next SLR selection (priority based)
    always @(live_SLR or SLRs_valid) begin:_SLR_PRI_
        integer idx;
        next_SLR = live_SLR;
        for (idx = (SLR_COUNT-1); idx >= 0; idx = idx - 1)
            if (SLRs_valid[idx]) next_SLR = idx; //Lowest index wins
    end

    //Next SLR assignment (sticky...only change if current not "valid")
    always @(posedge clk) begin:_SLR_REG_
        if (rst_r) begin
            live_SLR <= 0;
        end else if (SLR_switch) begin
            live_SLR <= next_SLR;
        end
    end


//Drive active SLR to SLR-Master
    wire        SLR_valid        = SLRs_valid       [ live_SLR ];
    wire [31:0] SLR_frame        = SLRs_frame       >> (live_SLR*32),//[(live_SLR*32)+31 -: 32],
                  SLR_color_fill = SLRs_color_fill  >> (live_SLR*32),//[(live_SLR*32)+31 -: 32],
                  SLR_color_edge = SLRs_color_edge  >> (live_SLR*32);//[(live_SLR*32)+31 -: 32];
    wire [ 9:0] SLR_row          = SLRs_row         >> (live_SLR*10),//[(live_SLR*10)+ 9 -: 10],
                  SLR_col_start  = SLRs_col_start   >> (live_SLR*10),//[(live_SLR*10)+ 9 -: 10],
                  SLR_col_finish = SLRs_col_finish  >> (live_SLR*10);//[(live_SLR*10)+ 9 -: 10];


//SLR-Master: Drive DDR lines to write a "run" (series) of pixels
    localparam
        MH_RSET     = 0, //Performing or coming out of reset     <=-._
        MH_IDLE     = 1, //Ready for initiation                       \
        MH_DDR1     = 2, //1st-half DDR-write     <----------------=\?/
        MH_DDR2     = 3; //2nd-half DDR-write; or done     -------->_/
    localparam MH__LAST = MH_DDR2;
    localparam [MH__LAST:0] MS__DEAD = 0, //Initial or fault (requires reset)
        MS_RSET = (1<<MH_RSET),  MS_IDLE = (1<<MH_IDLE),
        MS_DDR1 = (1<<MH_DDR1),  MS_DDR2 = (1<<MH_DDR2);

    reg  [MH__LAST:0] ns_M, cs_M = MS__DEAD;
    reg  [ 9:0] y;
//  reg  [ 9:0] x, x_finish; //Old "stride 1" version
    reg  [ 6:0] X8, X8_last;
    reg  isFIRST8; //Manipulate a register rather than using extra comparator

    reg  [ 7:0] r_edge_L, r_fill_L, r_edge_R, r_fill_R;
    reg  [ 3:0] maskW;
    reg  [31:0] maskC [3:0]; //Array rather than "bus style" vector concatenation

    wire [ 9:0] x = {X8[6:0], 3'b000}; //Truncate to first pixel in chunk of 8 (match memory width)
    wire [ 5:0] framebits = SLR_frame[27:22];
    wire [31:0] cpu_addr = {4'h1, framebits[5:0], y[9:0], x[9:3], 5'b00}; //CPU "byte" address
    wire isLAST8 = (X8 >= X8_last); //(x >= x_finish)

    //Sub-Offsets & Active-Lo byte-enable masks for start/finish edge cases (LITTLEWORDIAN)
    wire [ 2:0] offset_start  = SLR_col_start [2:0];
    wire [ 2:0] offset_finish = SLR_col_finish[2:0];
    wire [ 7:0] c_edge_L = (15'b111_1111_0111_1111 >> offset_start);
    wire [ 7:0] c_fill_L = (15'b111_1111_1000_0000 >> offset_start);
    wire [ 7:0] c_edge_R = (15'b111_1111_0111_1111 >> offset_finish);
    wire [ 7:0] c_fill_R = (15'b000_0000_1111_1111 >> offset_finish);

    wire [ 7:0] edge8 = ( (r_edge_L | {8{!isFIRST8}}) & (r_edge_R | {8{!isLAST8}}) );
    wire [ 7:0] fill8 = ( (r_fill_L & {8{ isFIRST8}}) | (r_fill_R & {8{ isLAST8}}) );
//  wire [ 7:0] mask8 = (edge8 & fill8); //"either is active" (active-lo)
    wire        hi4 = (LITTLEWORDIAN) ? cs_M[MH_DDR1] : cs_M[MH_DDR2];

    wire wdr_advance1 = (!wdf_full && !caf_full);
    wire wdr_advance2 = (!wdf_full);

//Unroll a mask computation for each of 4 pixels (each includes DDR1/2 mux)
    always @(*) begin:_MASK_
        integer b;
        for (b=0; b<4; b=b+1) begin
            maskW[b] = 1'b0;            //Default to ENABLE pixel write
            maskC[b] = SLR_color_edge;  //  in EDGE color
            casez ({hi4, edge8[b], fill8[b], edge8[4+b], fill8[4+b]})
                5'b0_11_zz: maskW[b] = 1'b1; //AND of active-lo -=> OR the two enables
                5'b0_10_zz: maskC[b] = SLR_color_fill; //When only FILL active
                5'b1_zz_11: maskW[b] = 1'b1; //As above, for 2nd pair
                5'b1_zz_10: maskC[b] = SLR_color_fill; // (hi-bit is "mux" selector)
            endcase //Flat "muxie-style" (defaults  & casez keep it short); probly confusing!
        end
    end

//Master-State machine predict Next State
    always @(*) begin:_NS_
        ns_M = cs_M; //Default: Hold prior state if UNASSIGNED
        case (cs_M) //TODO:Create MM_xyz "masks" & use Parallel-Case approach
            MS_RSET: if (!rst_r) ns_M = MS_IDLE; //Come out with a full cycle
            MS_IDLE: if (SLR_valid) ns_M = MS_DDR1; //We know we are ready since MS_IDLE
            MS_DDR1: if (wdr_advance1) ns_M = MS_DDR2;
            MS_DDR2: if (wdr_advance2) ns_M = (isLAST8) ? MS_IDLE : MS_DDR1;
            default: ns_M = MS__DEAD;
        endcase
    end

//Master-State machine respond to Current State
    always @(posedge clk) begin:_CS_
        if (rst_r) cs_M <= MS_RSET; else cs_M <= ns_M;

        case (cs_M)
            MS_RSET: begin
                //Nothing important to reset (state resets above)
            end
            MS_IDLE: if (SLR_valid) begin
                y         <= SLR_row;
                X8        <= SLR_col_start[9:3];  //Truncate to a chunk of 8 pixels
                X8_last   <= SLR_col_finish[9:3]; //  so stride matches memory width
                isFIRST8  <= 1'b1;
                {r_edge_L, r_fill_L} <= {c_edge_L, c_fill_L};
                {r_edge_R, r_fill_R} <= {c_edge_R, c_fill_R};
            end
            MS_DDR1: begin
                //NADA
            end
            MS_DDR2: if (wdr_advance2) begin
                X8 <= (X8+1);
                isFIRST8 <= 1'b0;
            end
        endcase
    end

    assign SLR_MASTER_ready = (cs_M[MH_IDLE]);
    assign caf_addr  = {3'b000, cpu_addr[27:3]}; //WAS:6'd0, Make 31-bit DDR-address (@double-word)
    assign caf_wren     = (cs_M[MH_DDR1]);
    assign wdf_wren    = (cs_M[MH_DDR1] || cs_M[MH_DDR2]);
    assign wdf_data      = (LITTLEWORDIAN)
                            ? { maskC[3], maskC[2], maskC[1], maskC[0] }
                            : { maskC[0], maskC[1], maskC[2], maskC[3] };
    assign wdf_mask = (LITTLEWORDIAN)
                            ? { {4{maskW[3]}}, {4{maskW[2]}}, {4{maskW[1]}}, {4{maskW[0]}} }
                            : { {4{maskW[0]}}, {4{maskW[1]}}, {4{maskW[2]}}, {4{maskW[3]}} };


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
        endcase //Flat version of {3{DDR1~^DDR2}} | (4'b0111 >> x[2:0]) [Or close]!
    end
*/

endmodule
