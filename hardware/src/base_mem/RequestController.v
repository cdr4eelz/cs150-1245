//----------------------------------------------------------------------------
// Module: RequestControler.v
// Author: James Parker
//
// This module is designed to give the caches the illusion of having exclusive
//   access to the DDR2 FIFOs. Additionally, it interleaves requests when both
//   caches attempt to access DDR2 simultaneously. The instruction cache is
//   given priority (i.e. it's requests are serviced first).
//
// When there are access collisions, this module tells the data cache that the
//   FIFOs are full, essentially stalling the cache until the icache finishes.
//
// There are some optimizations this module does not attempt that you may
//   experiment with for the performance contest:
//      - Recognizing duplicate read requests and performing only one DDR2 access
//      - Giving reads priority (because we don't block on completing writes)
//
// v2 Changes:
// To support the framebuffer, there are three new access paths:
//      - Write-only path from the line engine to DDR2
//      - Write-only path from the color filler to the DDR2
//      - Read-only path from DDR2 to a module that feeds DVI with pixels.
//
// v3 changes: (Ian Juch)
// To support graphics command processor:
//      - Read only path to access the instructions from DDR2
//-----------------------------------------------------------------------------

module RequestController(
    input           clk,
    input           rst,

    // inputs from the DDR2 FIFOs:
    input               caf_full,
    input               wdf_full,
    input               rdf_valid,
    // output to the DDR2 FIFOs:
    output reg          caf_wren,
    output reg [  2:0]  caf_gcmd_data,
    output reg [ 30:0]  caf_addr,
    output reg          wdf_wren,
    output reg [ 15:0]  wdf_mask,
    output reg [127:0]  wdf_data,
    output              rdf_rden,

    // Instruction-cache inputs (Read-Write-Stall):
    input           inst_caf_wren,
    input [  2:0]   inst_caf_data,
    input [ 30:0]   inst_caf_addr,
    input           inst_wdf_wren,
    input [ 15:0]   inst_wdf_mask,
    input [127:0]   inst_wdf_data,
    input           inst_rdf_rden,
    input           inst_stall,
    // Data-cache inputs (Read-Write-Stall):
    input           data_caf_wren,
    input [  2:0]   data_caf_data,
    input [ 30:0]   data_caf_addr,
    input           data_wdf_wren,
    input [ 15:0]   data_wdf_mask,
    input [127:0]   data_wdf_data,
    input           data_rdf_rden,
    input           data_stall,
    // GraphicsProcessor inputs (Read-only):
    //   Note: Read-only uses a small subset of fifo signals
    input           gcmd_caf_wren,
    input [ 30:0]   gcmd_caf_addr,
    input           gcmd_rdf_rden,
    // PixelFeeder inputs (Read-only):
    input           pixf_caf_wren,
    input [ 30:0]   pixf_caf_addr,
    input           pixf_rdf_rden,
    // FrameFiller inputs (Read-only):
    //   Note: For Write-only, use a subset of fifo signals
    input           fill_caf_wren,
    input [ 30:0]   fill_caf_addr,
    input           fill_wdf_wren,
    input [ 15:0]   fill_wdf_mask,
    input [127:0]   fill_wdf_data,
    // LineEngine inputs (Write-only):
    input           line_caf_wren,
    input [ 30:0]   line_caf_addr,
    input           line_wdf_wren,
    input [ 15:0]   line_wdf_mask,
    input [127:0]   line_wdf_data,
    // Bypass-the-cache inputs (Write-only):
    input           bpas_caf_wren,
    input [ 30:0]   bpas_caf_addr,
    input           bpas_wdf_wren,
    input [ 15:0]   bpas_wdf_mask,
    input [127:0]   bpas_wdf_data,

    // Instruction-cache outputs:
    output          inst_caf_full,
    output          inst_wdf_full,
    output          inst_rdf_valid,
    // Data-cache outputs:
    output          data_caf_full,
    output          data_wdf_full,
    output          data_rdf_valid,
    // GraphicsProcessor outputs:
    output          gcmd_caf_full,
    output          gcmd_rdf_valid,
    // PixelFeeder outputs:
    output          pixf_caf_full,
    output          pixf_rdf_valid,
    // FrameFiller outputs:
    output          fill_caf_full,
    output          fill_wdf_full,
    // LineEngine outputs:
    output          line_caf_full,
    output          line_wdf_full,
    // Bypass-the-cache outputs:
    output          bpas_caf_full,
    output          bpas_wdf_full
);


    localparam NULL_ACCESS  = 3'b000;
    localparam DATA_ACCESS  = 3'b001;
    localparam INST_ACCESS  = 3'b010;
    localparam FILL_ACCESS  = 3'b011;
    localparam LINE_ACCESS  = 3'b100;
    localparam PIXF_ACCESS  = 3'b101;
    localparam BPAS_ACCESS  = 3'b110;
    localparam GCMD_ACCESS  = 3'b111;

    // To facilitate the switch to asserting wr_en's even when fifos are full,
    //   we have to AND the full signals so data and cmds are written together.
    wire ff_full;
    assign ff_full = (caf_full || wdf_full);

    // New approach: icache and dcache don't stream reads. Keep
    //   a count of each read and then remember the number for
    //   the caches. Should be okay if they wrap around; 11 bits
    //   so that they are larger than max fifo size.

    reg  [ 2:0] fifo_access;
    reg  [10:0] inst_req_num,   data_req_num,   gcmd_req_num;
    reg  [ 1:0] inst_req_valid, data_req_valid, gcmd_req_valid;
    reg  [10:0] issued_reads;
    reg  [11:0] serviced_reads; // extra bit b/c 2 chunks - use [11:1] to cmpare.

    wire fetch_issued;
    assign fetch_issued = caf_wren && (caf_gcmd_data == 3'b001) && !ff_full;

    always @(posedge clk) begin
        if(rst)
            issued_reads   <= 11'b0;
        else if(fetch_issued)
            issued_reads   <= issued_reads + 11'b1;

        if(rst)
            serviced_reads <= 12'b0;
        else if(rdf_valid)
            serviced_reads <= serviced_reads + 1;

        if(rst) begin
            inst_req_num   <= 10'b0;
            inst_req_valid <= 2'b0;
        end else if(fifo_access == INST_ACCESS && fetch_issued) begin
            inst_req_num   <= issued_reads;
            inst_req_valid <= 2'b10;
        end else if(inst_req_num == serviced_reads[11:1] && inst_req_valid != 2'b0 && rdf_valid) begin
            inst_req_num   <= inst_req_num;
            inst_req_valid <= inst_req_valid - 1;
        end

        if(rst) begin
            data_req_num   <= 10'b0;
            data_req_valid <= 2'b0;
        end else if(fifo_access == DATA_ACCESS && fetch_issued) begin
            data_req_num   <= issued_reads;
            data_req_valid <= 2'b10;
        end else if(data_req_num == serviced_reads[11:1] && data_req_valid != 2'b0 && rdf_valid) begin
            data_req_num   <= data_req_num;
            data_req_valid <= data_req_valid - 1;
        end

        if(rst) begin
            gcmd_req_num   <= 10'b0;
            gcmd_req_valid <= 2'b0;
        end else if(fifo_access == GCMD_ACCESS && fetch_issued) begin
            gcmd_req_num   <= issued_reads;
            gcmd_req_valid <= 2'b10;
        end else if(gcmd_req_num == serviced_reads[11:1] && gcmd_req_valid != 2'b0 && rdf_valid) begin
            gcmd_req_num   <= gcmd_req_num;
            gcmd_req_valid <= gcmd_req_valid - 1;
        end
    end


    // this can go straight through, only logic req'd is for directing the data
    wire inst_read, data_read, gcmd_read;
    assign inst_read = |inst_req_valid && (inst_req_num == serviced_reads[11:1]);
    assign data_read = |data_req_valid && (data_req_num == serviced_reads[11:1]);
    assign gcmd_read = |gcmd_req_valid && (gcmd_req_num == serviced_reads[11:1]);

    assign rdf_rden = inst_read ? inst_rdf_rden :
                       data_read ? data_rdf_rden :
                       gcmd_read ? gcmd_rdf_rden :
                                   pixf_rdf_rden;

    // directing the data is now straightforward: we give it to current_reader
    assign inst_rdf_valid = (inst_read) ? rdf_valid : 1'b0;
    assign data_rdf_valid = (data_read) ? rdf_valid : 1'b0;
    assign gcmd_rdf_valid = (gcmd_read) ? rdf_valid : 1'b0;
    assign pixf_rdf_valid = (inst_read || data_read || gcmd_read)
                              ? 1'b0 : rdf_valid;


    //**************************************************************************
    // This section is for determining the signals to the DDR2 fifos and the
    // full signals to send to the various access paths.
    //************************************************************************

    // The "reserved" signals prevent higher-priority paths from interrupting
    //    a write "wdf-pair" already in-progress (guards the second wdf write).
    //    Reads are "guarded" implicitly by the request numbering scheme.

    reg  fill_reserved, line_reserved, bpas_reserved;
    wire reserved;

    always @(posedge clk) begin
        if(rst)
            fill_reserved <= 1'b0;
        else if(fifo_access == FILL_ACCESS && !ff_full)
            fill_reserved <= !fill_reserved;

        if(rst)
            line_reserved <= 1'b0;
        else if(fifo_access == LINE_ACCESS && !ff_full)
            line_reserved <= !line_reserved;

        if(rst)
            bpas_reserved <= 1'b0;
        else if(fifo_access == BPAS_ACCESS && !ff_full)
            bpas_reserved <= !bpas_reserved;
    end

    assign reserved = |{fill_reserved,line_reserved,bpas_reserved};

    always @(*) begin
        // Access is given in the order of:
        //   inst, data, gcmd, pixl, fill, line, bpas.
        if     ((inst_caf_wren || inst_wdf_wren) && !reserved) begin
            fifo_access  = INST_ACCESS;
            // read-write path for icache -> fifo signals:
            caf_gcmd_data   = inst_caf_data;
            caf_addr  = inst_caf_addr;
            caf_wren     = inst_caf_wren  && !ff_full;
            wdf_data      = inst_wdf_data;
            wdf_mask = inst_wdf_mask;
            wdf_wren    = inst_wdf_wren && !ff_full;
        end
        else if((data_caf_wren || data_wdf_wren) && !reserved) begin
            fifo_access  = DATA_ACCESS;
            // read-write path for dcache -> fifo signals:
            caf_gcmd_data   = data_caf_data;
            caf_addr  = data_caf_addr;
            caf_wren     = data_caf_wren  && !ff_full;
            wdf_data      = data_wdf_data;
            wdf_mask = data_wdf_mask;
            wdf_wren    = data_wdf_wren && !ff_full;
        end

        else if((gcmd_caf_wren) && !reserved) begin
            fifo_access  = GCMD_ACCESS;
            // read-only path for GraphicsController:
            caf_gcmd_data   = 3'b001;
            caf_addr  = gcmd_caf_addr;
            caf_wren     = gcmd_caf_wren &&  !ff_full;
            wdf_data      = 128'bx; // doesn't matter
            wdf_mask = 16'hFFFF; // not writing
            wdf_wren    = 1'b0; //not writing
        end
        else if(pixf_caf_wren && !reserved) begin
            fifo_access  = PIXF_ACCESS;
            // read-only path for PixelFeeder:
            caf_gcmd_data   = 3'b001;
            caf_addr  = pixf_caf_addr;
            caf_wren     = pixf_caf_wren &&  !ff_full;
            wdf_data      = 128'bx; // doesn't matter
            wdf_mask = 16'hFFFF; // not writing
            wdf_wren    = 1'b0; //not writing
        end

        else if((fill_caf_wren || fill_wdf_wren) && (!reserved || fill_reserved)) begin
            fifo_access  = FILL_ACCESS;
            // write-only path for FrameFiller:
            caf_gcmd_data   = 3'b000;
            caf_addr  = fill_caf_addr;
            caf_wren     = fill_caf_wren  && !ff_full;
            wdf_data      = fill_wdf_data;
            wdf_mask = fill_wdf_mask;
            wdf_wren    = fill_wdf_wren && !ff_full;
        end
        else if((line_caf_wren || line_wdf_wren) && (!reserved || line_reserved)) begin
            fifo_access  = LINE_ACCESS;
            // write-only path for LineEngine:
            caf_gcmd_data   = 3'b000;
            caf_addr  = line_caf_addr;
            caf_wren     = line_caf_wren  && !ff_full;
            wdf_data      = line_wdf_data;
            wdf_mask = line_wdf_mask;
            wdf_wren    = line_wdf_wren && !ff_full;
        end
        else if((bpas_caf_wren || bpas_wdf_wren) && (!reserved || bpas_reserved)) begin
            fifo_access  = BPAS_ACCESS;
            // write-only path for cache-bypass:
            caf_gcmd_data   = 3'b000;
            caf_addr  = bpas_caf_addr;
            caf_wren     = bpas_caf_wren  && !ff_full;
            wdf_data      = bpas_wdf_data;
            wdf_mask = bpas_wdf_mask;
            wdf_wren    = bpas_wdf_wren && !ff_full;
        end

        else begin
            fifo_access  = NULL_ACCESS;
            // in the default case, both need to see the actual fifo full
            //   signals, otherwise the cache will never attempt to write. for
            //   the other signals, we don't care, so just choose icache.
            caf_gcmd_data   = inst_caf_data;
            caf_addr  = inst_caf_addr;
            caf_wren     = 1'b0;
            wdf_data      = inst_wdf_data;
            wdf_mask = inst_wdf_mask;
            wdf_wren    = 1'b0;
        end
    end


    // Finally, based on the cache accessing, the fifo signals need to be set:
    //    (checking against fifo_access implicitly checks reserved)

    //Read-Write
    assign inst_caf_full  = (fifo_access == INST_ACCESS) ? ff_full : 1'b1;
    assign inst_wdf_full = (fifo_access == INST_ACCESS) ? ff_full : 1'b1;
    assign data_caf_full  = (fifo_access == DATA_ACCESS) ? ff_full : 1'b1;
    assign data_wdf_full = (fifo_access == DATA_ACCESS) ? ff_full : 1'b1;
    //Read-only
    assign gcmd_caf_full  = (fifo_access == GCMD_ACCESS) ? ff_full : 1'b1;
    assign pixf_caf_full  = (fifo_access == PIXF_ACCESS) ? ff_full : 1'b1;
    //Write-only
    assign fill_caf_full  = (fifo_access == FILL_ACCESS) ? ff_full : 1'b1;
    assign fill_wdf_full = (fifo_access == FILL_ACCESS) ? ff_full : 1'b1;
    assign line_caf_full  = (fifo_access == LINE_ACCESS) ? ff_full : 1'b1;
    assign line_wdf_full = (fifo_access == LINE_ACCESS) ? ff_full : 1'b1;
    assign bpas_caf_full  = (fifo_access == BPAS_ACCESS) ? ff_full : 1'b1;
    assign bpas_wdf_full = (fifo_access == BPAS_ACCESS) ? ff_full : 1'b1;

endmodule
