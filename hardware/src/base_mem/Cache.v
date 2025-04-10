//NOTE:COLT45: LITTLEWORDIAN allows natural ordering of 32-bit words within 256-bit DDR chunks

//----------------------------------------------------------------------------
// Module: Cache
// Inputs:
//    clk     : clock signal, same as CPU
//    rst     : system reset signal
//    address : 32-bit memory address
//    din     : 32-bit block of data
//    we      : 4-bit write mask
//    re      : read enable (should be high only when we = 4'b0)
//    caf_full: control signal for the address/cmd fifo
//    wdf_full: control signal for write data fifo
//    rdf_wren: control signal from DDR3 read data fifo
//    rdf_data: 128-bits from DDR3 Read-Data-Fifo WAS:(2x back-to-back per read-cmd)
//
// Outputs:
//    stall   : indicates the CPU should STALL
//    dout    : 32-bit Data-OUT result after a read
//    caf_wren: WRite ENable for Command/Address Fifo
//    caf_cadr: {3-bit-Cmd,28-bit-Address} Double-Request for Command/Address Fifo
//    wdf_mdat: {16-bit-Mask,128-bit-DATa} input (must issue 2x per write-cmd)
//    wdf_wren: WRite-ENable scalar for ddr2 Write-Data-Fifo
//    rdf_rden: ReaD-ENable  scalar for ddr2  Read-Data-Fifo
//
//----------------------------------------------------------------------------
`include "cache.vh"

//`default_nettype none

module Cache #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input wire          clk,
    input wire          rst,
    input wire[31:0]    addr,
    input wire[31:0]    din,
    input wire[3:0]     we,
    input wire          re,
//DDR-FIFO inputs:
    input wire          caf_full,
    input wire          wdf_full,
    input wire          rdf_wren,
    input wire[127:0]   rdf_data,
//DDR-FIFO outputs:
    output wire         rdf_rden,
    output wire[30:0]   caf_cadr, //{cmd-3,addr-28}  WAS: [33:0]
    output wire         caf_wren,
    output wire[143:0]  wdf_mdat, //{mask-16,data-128}
    output wire         wdf_wren,
// Control/Result signals:
    output wire         stall,
    output wire[31:0]   dout,
// Needed for set-associative cache
    output wire         tag_hit,
    output wire         tag_valid,
// Debug state machine current-state:
    output wire[3:0]    DBG_cache_cs
);

    // State declarations:
    localparam  IDLE        = 3'd0, // 000
                WRITE1      = 3'd1, // 001
                WRITE2      = 3'd2, // 010
                FETCH1      = 3'd3, // 011
                FETCH2      = 3'd4, // 100
                READ1       = 3'd5, // 101
                READ2       = 3'd6, // 110
                CWRITEB     = 3'd7; // 111

    //registers:
    // state for DDR3 FSM
    (* mark_debug = "true" *) reg [2:0] current_state, next_state;
    (* mark_debug = "true" *) wire isWriting, isFetching, isReading, isSecond;

    // register to hold first 128-bits read back
    // from DDR3
    (* mark_debug = "true" *) reg [127:0]   first_read;

    // register data in to write into the cache
    // either:
    // a) 1 cycle later - after a tag check
    // b) many cycles later - after doing a fetch from DDR3
    (* mark_debug = "true" *) reg [31:0]    din_hold;

    // register address
    (* mark_debug = "true" *) reg [31:0]    addr_hold;

    // register read and write enables
    (* mark_debug = "true" *) reg           re_hold;
    (* mark_debug = "true" *) reg [3:0]     we_hold;

    (* mark_debug = "true" *) wire mem_en;
    (* mark_debug = "true" *) wire [31:0] data_we;
    (* mark_debug = "true" *) wire tag_we;
    (* mark_debug = "true" *) wire [`SZ_CACHELINE-1:0] data;

    wire [`SZ_CACHELINE-1:0] data_line_out;
    wire [`SZ_TAGLINE-1:0] tag_line_out;
    wire [`SZ_CACHELINE-1:0] data_line_in;
    wire [`SZ_TAGLINE-1:0] tag_line_in;

    reg [`SZ_CACHELINE-1:0] active_data_line;

//  wire [`SZ_OFFSET-1:0] offset  = (LITTLEWORDIAN) ? ~addr[`IDX_ADDR_OFFSET]
//                                                  : addr[`IDX_ADDR_OFFSET];
    wire [`SZ_INDEX-1:0] index    = addr[`IDX_ADDR_INDEX];
//  wire [`SZ_TAG-1:0] tag        = addr[`IDX_ADDR_TAG];

    wire [`SZ_OFFSET-1:0] offset_hold  = (LITTLEWORDIAN) ? ~addr_hold[`IDX_ADDR_OFFSET]
                                                         : addr_hold[`IDX_ADDR_OFFSET];
    wire [`SZ_INDEX-1:0] index_hold    = addr_hold[`IDX_ADDR_INDEX];
    wire [`SZ_TAG-1:0] tag_hold        = addr_hold[`IDX_ADDR_TAG];

    wire [31:0] we_mask_hold;

    wire write_hit_hold;
    wire tag_equal;
    wire read_miss;

    // block ram for the cache:
    // 8kb
    // 256 rows / 32 bytes per row
    cache_data_blk_ram cache_data(
        .clka(clk),
        .ena(mem_en),
        .wea(data_we),
        .addra(index_hold),
        .dina(data_line_in),
        .clkb(clk),
        .rstb(rst),
        .enb(mem_en),
        .addrb(index),
        .doutb(data_line_out));

    cache_tag_blk_ram cache_tag(
        .clka(clk),
        .ena(mem_en),
        .wea(tag_we),
        .addra(index_hold),
        .dina(tag_line_in),
        .clkb(clk),
        .rstb(rst),
        .enb(mem_en),
        .addrb(index),
        .doutb(tag_line_out));

    // Assignments for the cache block ram:
    assign mem_en  = (next_state == IDLE) || (|data_we) || re;
    assign data_we = (next_state == CWRITEB) ? 32'hFFFFFFFF :
                      {32{write_hit_hold}} & we_mask_hold;
    assign tag_we = (next_state == CWRITEB) || (write_hit_hold);

    assign we_mask_hold = {28'b0, we_hold} << {offset_hold, 2'b0};


    // Some signals to make the FSM cleaner:
    assign tag_valid = tag_line_out[`IDX_TAG_VALID];
    assign tag_equal = tag_line_out[`IDX_TAG_TAG] == tag_hold;
    assign tag_hit = tag_valid && tag_equal;

    assign write_hit_hold = we_hold && tag_hit;

    assign read_miss = re_hold && !tag_hit;

    localparam STUCK_MAX_CYCLES = 8'd48;
    (* mark_debug = "true" *) reg [7:0] stuckCycles;
    (* mark_debug = "true" *) wire stuckTrigger = (stuckCycles == 0);
    (* mark_debug = "true" *) reg [31:0] stuckResets;
    assign DBG_cache_cs = {stuckTrigger, current_state};

    // synchronous logic:
    always @(posedge clk) begin
        if(rst || (current_state == IDLE) || (next_state != current_state)) begin
            stuckCycles <= STUCK_MAX_CYCLES;
        end else if(!stuckTrigger) begin
            stuckCycles <= stuckCycles - 1;
        end else begin
            // next_state change will hopefully avoid repeated increments!
            stuckResets <= stuckResets + 1;
        end

        if(rst)
            current_state <= IDLE;
        else
            current_state <= next_state;

        if(rst) begin
            addr_hold <= 32'h_0000_0000;
            re_hold   <= 1'b0;
            we_hold   <= 4'b_0000;
            din_hold  <= 32'h_0000_0000;
        end else if((next_state == IDLE)) begin //&& (|we || (re == 1'b1))) begin
            addr_hold <= addr;
            re_hold   <= re;
            we_hold   <= we;
            din_hold  <= din;
        end

        if(rst)
            first_read = 128'd0;
        else if(current_state == READ1)
            first_read <= rdf_data;

        if(rst)
            active_data_line = 256'd0;
        else if(current_state == IDLE)
            active_data_line <= data_line_out;
        else if(next_state == CWRITEB)
            active_data_line <= {first_read, rdf_data};
    end

    // State transition logic:
    always @(*) begin
        if(stuckTrigger && isReading) begin // Start again if results didn't reach us (major HACK)
            next_state = FETCH1;
        end else begin
            next_state = IDLE;
            case(current_state)
                IDLE   : next_state = (we_hold) ?                     WRITE1
                                        : ((read_miss) ? FETCH1  : IDLE );
                WRITE1 : next_state = (!wdf_full && !caf_full) ? WRITE2  : WRITE1;
                WRITE2 : next_state = (!wdf_full && !caf_full) ? IDLE    : WRITE2; // WAS: "!wdf_full" only
                FETCH1 : next_state = (             !caf_full) ? FETCH2  : FETCH1;
                FETCH2 : next_state = (             !caf_full) ? READ1   : FETCH2;
                READ1  : next_state = ( rdf_rden && rdf_wren ) ? READ2   : READ1;
                READ2  : next_state = ( rdf_rden && rdf_wren ) ? CWRITEB : READ2;
                CWRITEB: next_state = IDLE;
                default: next_state = IDLE;
            endcase
        end
    end

    assign  isWriting   = (current_state == WRITE1) || (current_state == WRITE2);
    assign  isFetching  = (current_state == FETCH1) || (current_state == FETCH2);
    assign  isReading   = (current_state == READ1 ) || (current_state == READ2 );
    assign  isSecond    = ((current_state == WRITE2)
                            || (current_state == FETCH2)
                            || (current_state == READ2));

    // FIFO output partial values:
    (* mark_debug = "true" *) wire [  2:0]  f_cmd;
    (* mark_debug = "true" *) wire [ 27:0]  f_addr_base, f_addr; //WAS: [30:0]
    (* mark_debug = "true" *) wire [127:0]  f_data;
    (* mark_debug = "true" *) wire [ 15:0]  f_mask;
    assign f_cmd  = (isWriting) ? 3'b000 : 3'b001; // Write = 0 : Read = 1
    assign f_addr_base = {3'b000, addr_hold[`IDX_ADDR_DRAM], 2'b00}; // WAS 6'b000000
    assign f_addr = (isSecond) ? (f_addr_base + 8) : f_addr_base;
    assign f_data = {4{din_hold}};
    // active low, so we have to flip the bits
    assign f_mask = (current_state == WRITE1) ? ~we_mask_hold[31:16] : ~we_mask_hold[15:0];

    // FIFO output assignments:
    assign caf_wren = (isWriting) || (isFetching);
    assign caf_cadr = {f_cmd, f_addr};
    assign wdf_wren = (isWriting);
    assign wdf_mdat = {f_mask, f_data};
    assign rdf_rden = isReading;

    // CPU output assignments:
    //   data out is either from cache line out or active cache line if there is a read
    assign data   = (current_state == IDLE) ? data_line_out[255:0] : active_data_line[255:0];
    assign dout   = (data >> {offset_hold, 5'b0});
    assign stall  = (next_state != IDLE);

    // If we're writing back data from DDR3, use the registered 128-bits
    // (first_read) and the current 128-bits from the read data FIFO
    assign data_line_in = (next_state == CWRITEB) ? {first_read, rdf_data} : {8{din_hold}};
    assign tag_line_in = {1'b0, 1'b1, tag_hold};

endmodule
