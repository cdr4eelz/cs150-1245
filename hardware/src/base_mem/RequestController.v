//----------------------------------------------------------------------------
// Module: RequestControler.v
// Author: James Parker
//
// This module is designed to give the caches the illusion of having exclusive
//   access to the DDR3 FIFOs. Additionally, it interleaves requests when both
//   caches attempt to access DDR3 simultaneously. The instruction cache is
//   given priority (i.e. it's requests are serviced first).
//
// When there are access collisions, this module tells the data cache that the
//   FIFOs are full, essentially stalling the cache until the icache finishes.
//
// There are some optimizations this module does not attempt that you may
//   experiment with for the performance contest:
//      - Recognizing duplicate read requests and performing only one DDR3 access
//      - Giving reads priority (because we don't block on completing writes)
//
// v2 Changes:
// To support the framebuffer, there are three new access paths:
//      - Write-only path from the line engine to DDR3
//      - Write-only path from the color filler to the DDR3
//      - Read-only path from DDR3 to a module that feeds DVI with pixels.
//
// v3 changes: (Ian Juch)
// To support graphics command processor:
//      - Read only path to access the instructions from DDR3
//-----------------------------------------------------------------------------


module RequestController(
    input  wire         clk,
    input  wire         rst,

    // DDR3 FIFOs (inputs);         [Master access]
    input  wire         caf_full,
    input  wire         wdf_full,
    input  wire         rdf_wren,

    // Inst-cache (inputs);         [Read/Write/Stall]
    input  wire         inst_caf_wren,
    input  wire[ 30:0]  inst_caf_cadr, // {cmd-3,addr-28} WAS: [33:0]
    input  wire         inst_wdf_wren,
    input  wire[143:0]  inst_wdf_mdat, // {mask-16,data-128}
    input  wire         inst_rdf_rden,
    input  wire         inst_stall,
    // Data-cache (inputs);         [Read/Write/Stall]
    input  wire         data_caf_wren,
    input  wire[ 30:0]  data_caf_cadr, // {cmd-3,addr-28} WAS: [33:0]
    input  wire         data_wdf_wren,
    input  wire[143:0]  data_wdf_mdat, // {mask-16,data-128}
    input  wire         data_rdf_rden,
    input  wire         data_stall,

    // GraphicsProcessor (inputs);  [Read-only]
    input  wire         gcmd_raf_wren,
    input  wire[ 27:0]  gcmd_raf_addr, //WAS: [30:0]
    input  wire         gcmd_rdf_rden,
    // PixelFeeder (inputs);        [Read-only]
    input  wire         pixf_raf_wren,
    input  wire[ 27:0]  pixf_raf_addr, //WAS: [30:0]
    input  wire         pixf_rdf_rden,
//NOTE:Read-only interface uses only subset of fifo signals

    // FrameFiller (inputs);        [Write-only]
    input  wire         fill_waf_wren,
    input  wire[ 27:0]  fill_waf_addr, //WAS [30:0]
    input  wire         fill_wdf_wren,
    input  wire[143:0]  fill_wdf_mdat,
    // LineEngine (inputs);         [Write-only]
    input  wire         line_waf_wren,
    input  wire[ 27:0]  line_waf_addr, //WAS [30:0]
    input  wire         line_wdf_wren,
    input  wire[143:0]  line_wdf_mdat,
    // Bypass (inputs);             [Write-only]
    input  wire         bpas_waf_wren,
    input  wire[ 27:0]  bpas_waf_addr, //WAS [30:0]
    input  wire         bpas_wdf_wren,
    input  wire[143:0]  bpas_wdf_mdat,
//NOTE:Write-only interface uses only subset of fifo signals

    // To DDR3 FIFOs (outputs);     [Master access]
    output reg          caf_wren,
    output reg [ 30:0]  caf_cadr, // {cmd-3,addr-28} WAS: [33:0]
    output reg          wdf_wren,
    output reg [143:0]  wdf_mdat,
    output wire         rdf_rden,

    // Inst-cache (outputs);        [Read/Write/Stall]
    output wire         inst_caf_full,
    output wire         inst_wdf_full,
    output wire         inst_rdf_wren,
    // Data-cache (outputs);        [Read/Write/Stall]
    output wire         data_caf_full,
    output wire         data_wdf_full,
    output wire         data_rdf_wren,

    // GraphicsProcessor (outputs); [Read-only]
    output wire         gcmd_raf_full,
    output wire         gcmd_rdf_wren,
    // PixelFeeder (outputs);       [Read-only]
    output wire         pixf_raf_full,
    output wire         pixf_rdf_wren,

    // FrameFiller (outputs);       [Write-only]
    output wire         fill_waf_full,
    output wire         fill_wdf_full,
    // LineEngine (outputs);        [Write-only]
    output wire         line_waf_full,
    output wire         line_wdf_full,
    // Bypass (outputs);            [Write-only]
    output wire         bpas_waf_full,
    output wire         bpas_wdf_full
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
    assign fetch_issued = caf_wren && (caf_cadr[30:28] == 3'b001) && !ff_full;

    always @(posedge clk) begin
        if(rst)
            issued_reads   <= 11'b0;
        else if(fetch_issued)
            issued_reads   <= issued_reads + 11'b1;

        if(rst)
            serviced_reads <= 12'b0;
        else if(rdf_wren)
            serviced_reads <= serviced_reads + 12'b1;

        if(rst) begin
            inst_req_num   <= 10'b0;
            inst_req_valid <= 2'b00;
        end else if((fifo_access == INST_ACCESS) && fetch_issued) begin
            inst_req_num   <= issued_reads;
            inst_req_valid <= 2'b10;
        end else if((inst_req_num == serviced_reads[11:1]) && |inst_req_valid && rdf_wren) begin
            inst_req_num   <= inst_req_num;
            inst_req_valid <= inst_req_valid - 2'b01;
        end

        if(rst) begin
            data_req_num   <= 10'b0;
            data_req_valid <= 2'b00;
        end else if((fifo_access == DATA_ACCESS) && fetch_issued) begin
            data_req_num   <= issued_reads;
            data_req_valid <= 2'b10;
        end else if((data_req_num == serviced_reads[11:1]) && |data_req_valid && rdf_wren) begin
            data_req_num   <= data_req_num;
            data_req_valid <= data_req_valid - 2'b01;
        end

        if(rst) begin
            gcmd_req_num   <= 10'b0;
            gcmd_req_valid <= 2'b00;
        end else if((fifo_access == GCMD_ACCESS) && fetch_issued) begin
            gcmd_req_num   <= issued_reads;
            gcmd_req_valid <= 2'b10;
        end else if((gcmd_req_num == serviced_reads[11:1]) && |gcmd_req_valid && rdf_wren) begin
            gcmd_req_num   <= gcmd_req_num;
            gcmd_req_valid <= gcmd_req_valid - 2'b01;
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
    assign inst_rdf_wren = (inst_read) ? rdf_wren : 1'b0;
    assign data_rdf_wren = (data_read) ? rdf_wren : 1'b0;
    assign gcmd_rdf_wren = (gcmd_read) ? rdf_wren : 1'b0;
    assign pixf_rdf_wren = (inst_read || data_read || gcmd_read)
                              ? 1'b0 : rdf_wren;


    //**************************************************************************
    // This section is for determining the signals to the DDR3 fifos and the
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
        else if((fifo_access == FILL_ACCESS) && !ff_full)
            fill_reserved <= !fill_reserved;

        if(rst)
            line_reserved <= 1'b0;
        else if((fifo_access == LINE_ACCESS) && !ff_full)
            line_reserved <= !line_reserved;

        if(rst)
            bpas_reserved <= 1'b0;
        else if((fifo_access == BPAS_ACCESS) && !ff_full)
            bpas_reserved <= !bpas_reserved;
    end

    assign reserved = |{fill_reserved,line_reserved,bpas_reserved};

    always @(*) begin
        // Access is given in the order of:
        //   inst, data, gcmd, pixl, fill, line, bpas
        if     ((inst_caf_wren || inst_wdf_wren) && !reserved) begin
            fifo_access = INST_ACCESS;
            // Read/Write path for icache -> fifo signals:
            caf_cadr  = inst_caf_cadr;
            caf_wren  = inst_caf_wren && !ff_full;
            wdf_mdat  = inst_wdf_mdat;
            wdf_wren  = inst_wdf_wren && !ff_full;
        end
        else if((data_caf_wren || data_wdf_wren) && !reserved) begin
            fifo_access = DATA_ACCESS;
            // Read/Write path for dcache -> fifo signals:
            caf_cadr  = data_caf_cadr;
            caf_wren  = data_caf_wren && !ff_full;
            wdf_mdat  = data_wdf_mdat;
            wdf_wren  = data_wdf_wren && !ff_full;
        end

        else if(gcmd_raf_wren && !reserved) begin
            fifo_access = GCMD_ACCESS;
            // Read-only path for GraphicsController:
            caf_cadr  = {3'b001, gcmd_raf_addr};
            caf_wren  = gcmd_raf_wren && !ff_full;
            wdf_mdat  = {16'hFFFF, 128'd0}; // doesn't matter ; not writing
            wdf_wren  = 1'b0; //not writing
        end
        else if(pixf_raf_wren && !reserved) begin
            fifo_access = PIXF_ACCESS;
            // Read-only path for PixelFeeder:
            caf_cadr  = {3'b001, pixf_raf_addr};
            caf_wren  = pixf_raf_wren && !ff_full;
            wdf_mdat  = {16'hFFFF, 128'd0}; // doesn't matter ; not writing
            wdf_wren  = 1'b0; //not writing
        end

        else if((fill_waf_wren || fill_wdf_wren) && (!reserved || fill_reserved)) begin
            fifo_access = FILL_ACCESS;
            // Write-only path for FrameFiller:
            caf_cadr  = {3'b000, fill_waf_addr};
            caf_wren  = fill_waf_wren && !ff_full;
            wdf_mdat  = fill_wdf_mdat;
            wdf_wren  = fill_wdf_wren && !ff_full;
        end
        else if((line_waf_wren || line_wdf_wren) && (!reserved || line_reserved)) begin
            fifo_access = LINE_ACCESS;
            // Write-only path for LineEngine:
            caf_cadr  = {3'b000, line_waf_addr};
            caf_wren  = line_waf_wren && !ff_full;
            wdf_mdat  = line_wdf_mdat;
            wdf_wren  = line_wdf_wren && !ff_full;
        end
        else if((bpas_waf_wren || bpas_wdf_wren) && (!reserved || bpas_reserved)) begin
            fifo_access = BPAS_ACCESS;
            // Write-only path for cache-bypass:
            caf_cadr  = {3'b000, bpas_waf_addr};
            caf_wren  = bpas_waf_wren && !ff_full;
            wdf_mdat  = bpas_wdf_mdat;
            wdf_wren  = bpas_wdf_wren && !ff_full;
        end

        else begin
            fifo_access = NULL_ACCESS;
            // In the default case, both need to see the actual fifo full
            //   signals, otherwise the cache will never attempt to write. for
            //   the other signals, we don't care, so just choose icache.
            // (NOTE:Seems like obsolete comment???)
            caf_cadr  = inst_caf_cadr;
            caf_wren  = 1'b0;
            wdf_mdat  = inst_wdf_mdat;
            wdf_wren  = 1'b0; //not writing
        end
    end


    // Finally, based on the cache accessing, the fifo signals need to be set:
    //   (checking against fifo_access implicitly checks reserved)

    //Read-Write:
    assign inst_caf_full  = (fifo_access == INST_ACCESS)  ? ff_full : 1'b1;
    assign inst_wdf_full  = (fifo_access == INST_ACCESS)  ? ff_full : 1'b1;
    assign data_caf_full  = (fifo_access == DATA_ACCESS)  ? ff_full : 1'b1;
    assign data_wdf_full  = (fifo_access == DATA_ACCESS)  ? ff_full : 1'b1;
    //Read-only:
    assign gcmd_raf_full  = (fifo_access == GCMD_ACCESS)  ? ff_full : 1'b1;
    assign pixf_raf_full  = (fifo_access == PIXF_ACCESS)  ? ff_full : 1'b1;
    //Write-only:
    assign fill_waf_full  = (fifo_access == FILL_ACCESS)  ? ff_full : 1'b1;
    assign fill_wdf_full  = (fifo_access == FILL_ACCESS)  ? ff_full : 1'b1;
    assign line_waf_full  = (fifo_access == LINE_ACCESS)  ? ff_full : 1'b1;
    assign line_wdf_full  = (fifo_access == LINE_ACCESS)  ? ff_full : 1'b1;
    assign bpas_waf_full  = (fifo_access == BPAS_ACCESS)  ? ff_full : 1'b1;
    assign bpas_wdf_full  = (fifo_access == BPAS_ACCESS)  ? ff_full : 1'b1;

endmodule
