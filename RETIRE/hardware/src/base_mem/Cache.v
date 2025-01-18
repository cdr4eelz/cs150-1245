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
//    rdf_wren: control signal from DDR2 read data fifo
//    rdf_data: 128-bits from ddr2 Read-Data-Fifo (2x back-to-back per read-cmd)
//
// Outputs:
//    stall   : indicates the CPU should STALL
//    dout    : 32-bit Data-OUT result after a read
//    caf_wren: WRite ENable for Command/Address Fifo
//    caf_cadr: {3-bit-Cmd,31-bit-Address} Double-Request for Command/Address Fifo
//    wdf_mdat: {16-bit-Mask,128-bit-DATa} input (must issue 2x per write-cmd)
//    wdf_wren: WRite-ENable scalar for ddr2 Write-Data-Fifo
//    rdf_rden: ReaD-ENable  scalar for ddr2  Read-Data-Fifo
//
//----------------------------------------------------------------------------
`include "cache.vh"

module Cache #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input           clk,
    input           rst,
    input [31:0]    addr,
    input [31:0]    din,
    input [3:0]     we,
    input           re,
    //DDR-FIFO inputs:
    input           caf_full,
    input           wdf_full,
    input           rdf_wren,
    input [127:0]   rdf_data,

    output          stall,
    output [31:0]   dout,
    output          rdf_rden,
    output [33:0]   caf_cadr,
    output          caf_wren,
    output [143:0]  wdf_mdat,
    output          wdf_wren,

    // Needed for set-associative cache
    output          tag_hit,
    output          tag_valid,
    output [2:0]    state
);

    // State declarations:
    localparam  IDLE     = 3'b000,
                WRITE1   = 3'b001,
                WRITE2   = 3'b010,
                FETCH    = 3'b011,
                READ1    = 3'b100,
                READ2    = 3'b101,
                CWRITEB  = 3'b110;

    //registers:
    // state for DDR2 FSM
    reg [2:0]     cs, ns;
    assign state = cs;
    // register to hold first 128-bits read back
    // from DDR2
    reg [127:0]   first_read;

    // register data in to write into the cache
    // either:
    // a) 1 cycle later - after a tag check
    // b) many cycles later - after doing a fetch from DDR2
    reg [31:0]    din_hold;

    // register address
    reg [31:0]    addr_hold;

    // register read and write enables
    reg           re_hold;
    reg [3:0]     we_hold;

    wire mem_en;
    wire [31:0] data_we;
    wire tag_we;
    wire [`SZ_CACHELINE-1:0] data;

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
    assign mem_en  = (ns == IDLE) || (|data_we) || re;
    assign data_we = (ns == CWRITEB) ? 32'hFFFFFFFF :
                      {32{write_hit_hold}} & we_mask_hold;
    assign tag_we = (ns == CWRITEB) || (write_hit_hold);

    assign we_mask_hold = {28'b0, we_hold} << {offset_hold, 2'b0};


    // Some signals to make the FSM cleaner:
    assign tag_valid = tag_line_out[`IDX_TAG_VALID];
    assign tag_equal = tag_line_out[`IDX_TAG_TAG] == tag_hold;
    assign tag_hit = tag_valid && tag_equal;

    assign write_hit_hold = we_hold && tag_hit;

    assign read_miss = re_hold && !tag_hit;

    // synchronous logic:
    always @(posedge clk) begin
        if(rst)
            cs <= IDLE;
        else
            cs <= ns;

        if(ns == IDLE) begin
            addr_hold <= addr;
            re_hold   <= re;
            we_hold   <= we;
            din_hold  <= din;
        end

        if(cs == READ1)
            first_read <= rdf_data;

        if(cs == IDLE)
            active_data_line <= data_line_out;
        else if(ns == CWRITEB)
            active_data_line <= {first_read, rdf_data};
    end

    // State transition logic:
    always @(*) begin
        ns = IDLE;
        case(cs)
            IDLE   : ns = (we_hold) ?                     WRITE1
                                    : ((read_miss) ? FETCH   : IDLE );
            WRITE1 : ns = (!wdf_full && !caf_full) ? WRITE2  : WRITE1;
            WRITE2 : ns = (!wdf_full             ) ? IDLE    : WRITE2;
            FETCH  : ns = (             !caf_full) ? READ1   : FETCH;
            READ1  : ns = (       rdf_wren       ) ? READ2   : READ1;
            READ2  : ns = (       rdf_wren       ) ? CWRITEB : READ2;
            CWRITEB: ns = IDLE;
            default: ns = IDLE;
        endcase
    end

    // FIFO output partial values:
    wire [  2:0]  f_cmd;
    wire [ 30:0]  f_addr;
    wire [127:0]  f_data;
    wire [ 15:0]  f_mask;
    assign f_cmd  = (cs == WRITE1) ? 3'b000 : 3'b001;
    assign f_addr = {6'b0, addr_hold[`IDX_ADDR_DRAM], 2'b0};
    assign f_data = {4{din_hold}};
    // active low, so we have to flip the bits
    assign f_mask = (cs == WRITE1) ? ~we_mask_hold[31:16] : ~we_mask_hold[15:0];

    // FIFO output assignments:
    assign caf_wren = (cs == WRITE1) || (cs == FETCH );
    assign caf_cadr = {f_cmd, f_addr};
    assign wdf_wren = (cs == WRITE1) || (cs == WRITE2);
    assign wdf_mdat = {f_mask, f_data};
    assign rdf_rden = (cs == READ1 ) || (cs == READ2 );

    // CPU output assignments:
    //   data out is either from cache line out or active cache line if there is a read
    assign data   = (cs == IDLE) ? data_line_out[255:0] : active_data_line[255:0];
    assign dout   = (data >> {offset_hold, 5'b0});
    assign stall  = (ns != IDLE);

    // If we're writing back data from DDR2, use the registered 128-bits
    // (first_read) and the current 128 bits from the read data FIFO
    assign data_line_in = (ns == CWRITEB) ? {first_read, rdf_data} : {8{din_hold}};
    assign tag_line_in = {1'b0, 1'b1, tag_hold};

endmodule
