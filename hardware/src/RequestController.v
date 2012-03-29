//----------------------------------------------------------------------------
// Module: RequestControler.v
// Author: James Parker
//
// This module is designed to give the caches the illusion of having exclusive
// access to the DDR2 FIFOs. Additionally, it interleaves requests when both
// caches attempt to access DDR2 simultaneously. The instruction cache is
// given priority (i.e. it's requests are serviced first).
//
// When there are access collisions, this module tells the data cache that the
// FIFOs are full, essentially stalling the cache until the icache finishes.
//
// There are some optimizations this module does not attempt that you may
// experiment with for the performance contest:
//   - Recognizing duplicate read requests and performing only one DDR2 access
//   - Giving reads priority (because we don't block on completing writes)
//
//-----------------------------------------------------------------------------

module RequestController(
    input           clk,
    input           rst,
    // inputs from the DDR2 FIFOs:
    input           af_full,
    input           wdf_full,
    input           rdf_valid,

    // inputs from the instruction cache:
    input            i_rdf_rd_en,
    input [2:0]      i_af_cmd_din,
    input [30:0]     i_addr_din,
    input            i_af_wr_en,
    input [127:0]    i_wdf_din,
    input [15:0]     i_wdf_mask_din,
    input            i_wdf_wr_en,
    input            i_stall,

    // inputs from the data cache:
    input            d_rdf_rd_en,
    input [2:0]      d_af_cmd_din,
    input [30:0]     d_addr_din,
    input            d_af_wr_en,
    input [127:0]    d_wdf_din,
    input [15:0]     d_wdf_mask_din,
    input            d_wdf_wr_en,
    input            d_stall,

    // output to the DDR2 FIFOs:
    output             rdf_rd_en,
    output reg [2:0]   af_cmd_din,
    output reg [30:0]  addr_din,
    output reg         af_wr_en,
    output reg [127:0] wdf_din,
    output reg [15:0]  wdf_mask_din,
    output reg         wdf_wr_en,

    // output to the instruction cache:
    output             i_rdf_valid,
    output             i_af_full,
    output             i_wdf_full,

    // output to the data cache:
    output             d_rdf_valid,
    output             d_af_full,
    output             d_wdf_full
);

    //*************************************************************************
    // This section enables interleaving of read requests by tracking the order
    // so that the data returned from the DDR2 can be directed properly.
    //*************************************************************************

    // In order to return the data to the proper cache, we need to keep
    // track of read request order. To do this, we will use a FIFO.
    localparam NONE      = 2'b00;
    localparam DCACHE    = 2'b01;
    localparam ICACHE    = 2'b10;

    // These params are different than above because we need an extra bit to
    // represent all of the sources, and we only need 2 bits to represent the
    // possible readers (can save 1 bit per entry in the requester FIFO)
    localparam NO_ACCESS     = 3'b000;
    localparam D_ACCESS      = 3'b001;
    localparam I_ACCESS      = 3'b010;

    // Some helper signals for the logic:
    wire       icache_read;
    wire       dcache_read;
    wire       request_fifo_wr_en;
    wire       request_fifo_full;
    wire [1:0] current_reader;
    wire       request_empty;
    wire       valid_count;
    reg        second_read;
    reg [1:0]  insert_source;
    reg [2:0]  fifo_access;

    // Check fifo_access here to make sure signal actually went through to
    // fifos
    assign icache_read = (fifo_access == I_ACCESS) && (i_af_cmd_din == 3'b001) && !af_full && !wdf_full;
    assign dcache_read = (fifo_access == D_ACCESS) && (d_af_cmd_din == 3'b001) && !af_full && !wdf_full;
    assign request_fifo_wr_en = af_wr_en  && (icache_read || dcache_read);

    // Create the input to the FIFO:
    always @(*) begin
        // pick the source to put in the "waiting fifo"
        if(icache_read)
            insert_source = ICACHE;
        else if(dcache_read)
            insert_source = DCACHE;
        else
            insert_source = NONE;
    end

    // Read logic:
    always @(posedge clk) begin
        if(rst) begin
            second_read <= 1'b0;
        end
        else if(rdf_valid && rdf_rd_en) begin
            // toggle because each requester expects 2 rdf_valids
            second_read <= second_read + 1'b1;
        end
    end

    assign valid_count = rdf_valid ? second_read : 1'b0;

    request_fifo req_fifo(
        .clk(clk),
        .rst(rst),
        .din(insert_source),
        .wr_en(request_fifo_wr_en),
        .rd_en(valid_count),
        .dout(current_reader),
        .valid(),
        .full(request_fifo_full),   // shouldn't happen & left unhandled
        .empty(request_empty));

    // this can go straight through, only logic req'd is for directing the data
    assign rdf_rd_en =  (current_reader == ICACHE && i_rdf_rd_en)
    || (current_reader == DCACHE && d_rdf_rd_en);

    // directing the data is now straightforward: we give it to current_reader
    assign i_rdf_valid =  current_reader == ICACHE ? rdf_valid : 1'b0;
    assign d_rdf_valid =  current_reader == DCACHE ? rdf_valid : 1'b0;


    //**************************************************************************
    // This section is for determining the signals to the DDR2 fifos and the
    // full signals to send to the various access paths.
    //************************************************************************


    always @(*) begin
        // Access is given in the order of icache, dcache, pixel feeder, color filler
        // line engine.
        if(i_af_wr_en || i_wdf_wr_en) begin
            fifo_access  = I_ACCESS;
            //icache -> fifo signals:
            af_cmd_din   = i_af_cmd_din;
            addr_din     = i_addr_din;
            af_wr_en     = i_af_wr_en && (!wdf_full &&  !af_full);
            wdf_din      = i_wdf_din;
            wdf_mask_din = i_wdf_mask_din;
            wdf_wr_en    = i_wdf_wr_en && (!wdf_full && !af_full);
        end
        else if(d_af_wr_en || d_wdf_wr_en) begin
            fifo_access  = D_ACCESS;
            af_cmd_din   = d_af_cmd_din;
            addr_din     = d_addr_din;
            af_wr_en     = d_af_wr_en && (!wdf_full && !af_full);
            wdf_din      = d_wdf_din;
            wdf_mask_din = d_wdf_mask_din;
            wdf_wr_en    = d_wdf_wr_en && (!wdf_full && !af_full);
        end
        else begin
            fifo_access  = NO_ACCESS;
            // in the default case, both need to see the actual fifo full
            // signals, otherwise the cache will never attempt to write.
            // for the other signals, we don't care, so just choose icache
            af_cmd_din   = i_af_cmd_din;
            addr_din     = i_addr_din;
            af_wr_en     = 1'b0;
            wdf_din      = i_wdf_din;
            wdf_mask_din = i_wdf_mask_din;
            wdf_wr_en    = 1'b0;
        end
    end

    // To facilitate the switch to asserting wr_en's even when fifos are full,
    // we have to and the full signals so data and cmds are written together.

    // finally, based on the cache accessing, the fifo signals need to be set:
    assign i_af_full = fifo_access == I_ACCESS ?  af_full || wdf_full : 1'b1;
    assign i_wdf_full = fifo_access == I_ACCESS ? wdf_full || af_full : 1'b1;


    assign d_af_full  = fifo_access == D_ACCESS ?  af_full || wdf_full : 1'b1;
    assign d_wdf_full = fifo_access == D_ACCESS ? wdf_full || af_full : 1'b1;

endmodule
