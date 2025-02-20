`timescale 1ns/1ps

`include "../src/gpu/gpcommands.vh"

module GPUTestbench;

`include "util_elog.vh"

    parameter LITTLEWORDIAN = 1, WATCH_SLR = 1;
    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600;

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  cpu_clk_g, rst_cpu_bus;
    initial cpu_clk_g = 0;
    always #(HalfCycle) cpu_clk_g = ~cpu_clk_g;

    reg          gp_vcode;
    wire         gp_vframe = gp_vcode; //TODO:Test separate gp_vframe
    reg  [ 31:0] gp_wcode, gp_wframe;
    wire [ 31:0] gp_rcode;
    wire [ 15:0] gp_status;
    wire           gp_fault      = gp_status[15];
    wire [  5:0]   gp_rframe     = gp_status[13:8];
    wire           ENGINES_ready = &gp_status[3:1];
    wire           gp_ready      = gp_status[0];
    wire         irq_gp_done;

    // Graphics Command Processor <=> RequestController wires:
    reg          gcmd_raf_full;
    wire         gcmd_raf_wren;
    wire [ 30:0] gcmd_raf_addr;
    wire         gcmd_rdf_rden;
    reg          gcmd_rdf_wren;
    reg  [127:0] rdf_data;

    // Bypass/ScanLineRunner <=> RequestController wires:
    reg          bpas_waf_full;
    wire         bpas_waf_wren;
    wire [ 30:0] bpas_waf_addr;
    reg          bpas_wdf_full;
    wire         bpas_wdf_wren;
    wire [ 15:0] bpas_wdf_mask;
    wire [127:0] bpas_wdf_data;
    wire [127:0] bpas_wdf_mdat = {bpas_wdf_mask,bpas_wdf_data};

    reg [0:1023] DDR2MEM;

/*
*** SAMPLE-2 GPCODE block ***
    0x4000:   FF_FFFFFF   # ERR!
    0x4004:   FF_FFFFFF   # ERR!
    0x4008:   FF_FFFFFF   # ERR!
    0x400C:   01_FFFFFF   # FILL: white
    0x4010:   0200_00FF   # LINE: green
    0x4014:   0010_0020   #   first-endpoint  (0x10, 0x20)
    0x4018:   001A_002B   #   second-endpoint (0x1A, 0x2B)
    0x401C:   03_1144EE   # ELIP: bluish
    0x4020:   0064_0064   #   center-point    (0x64, 0x64)
    0x4024:   000A_0014   #   dimensions-a/b  (0x0A, 0x14)
    0x4028:   0000_0000   # STOP.
    0x402C:   FF_FFFFFF   # ERR!
*/
wire [0:1023] GPCODE_SAMPLE2 = { //Ascending bit order
    32'hFF_FFFF00, 32'hFF_FFFF01, 32'hFF_FFFF02, 32'h01_FFFFFF,
    32'h02_00FF00, 32'h0010_0020, 32'h001A_002B, 32'h03_1144EE,
    32'h0064_0064, 32'h000A_0014, 32'h0000_0000, 32'hFF_FFFFFF,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0
};
/*
*** SAMPLE-3 GPCODE block ***
    0x4000:   03_808080   # ELIP: grey
    0x4004:   0032_0019   #   center-point    ( 50,  25)
    0x4008:   0020_0008   #   dimensions-a/b  ( 32,   8)
    0x400C:   0000_0000   # STOP.
*/
wire [0:1023] GPCODE_SAMPLE3 = { //Ascending bit order
    32'h03_808080, 32'h0032_0019, 32'h0020_0008, 32'h00_000000,
    128'b0,
    256'b0,
    512'b0
};

//Fake memory write monitoring
    integer CNT_waf=0, CNT_wdf=0;
    always @(posedge cpu_clk_g) begin
        //TODO:Optionally monitor these like LineEngineTestbench
        if (bpas_waf_wren && !bpas_waf_full) CNT_waf = CNT_waf+1;
        if (bpas_wdf_wren && !bpas_wdf_full) CNT_wdf = CNT_wdf+1;
    end
    initial begin
        bpas_waf_full = 1'b0; //TODO:Test backpressure on these
        bpas_wdf_full = 1'b0;
    end
    task CNT_RESET;
    begin
        CNT_waf=0; CNT_wdf=0;
    end endtask
    task CNT_SHOW;
    begin
        $display("\n\nCNT: waf=%0d wdf=%0d", CNT_waf, CNT_wdf);
    end endtask


    initial begin
        $display("GPU: Fake memory, real SLR/Engines...\n\n");
        #(Cycle);
        @(posedge cpu_clk_g);
        {gp_vcode, gp_wcode, gp_wframe} = 0;
        rst_cpu_bus = 1'b1;
        #(10*Cycle);
        rst_cpu_bus = 1'b0;
        #(Cycle);

        $display("\n\nGPU: Sample #2");
        force DDR2MEM = GPCODE_SAMPLE2;
        execGP( 32'h0000_400C, `STD_FRAME3 ); //Frame 3: 10C0_0000

        $display("\n\nGPU: Sample #3");
        force DDR2MEM = GPCODE_SAMPLE3;
        execGP( 32'h0000_4000,           1 ); //Frame 1: 1040_0000

        @(posedge cpu_clk_g);
        while (!ENGINES_ready) #(Cycle); // GP should have waited already
        $display("\n\nGPU: Done.");
        ELOG_TALLY;
        $finish();
    end

    task execGP;
        input [31:0] codebase;
        input [31:0] framebase;
    begin
        CNT_RESET();
        @(negedge cpu_clk_g);
        $display("gpu-TB: Wait & negedge align...");
        while (!gp_ready) #(Cycle); // wait for gp_ready
        gp_wcode = codebase;
        gp_wframe = framebase;
        gp_vcode = 1'b1;
        $strobe("gpu-TB: code=%h  frame=%h", gp_wcode, gp_wframe);
        #(Cycle);
        gp_vcode = 1'b0;
        gp_wcode = 32'bz;
        $monitor("gpu-TB: procframe==%h  interrupt==%b  fault==%b",
                 gp_rframe, irq_gp_done, gp_fault);
        while (!gp_ready) begin
//            if (wdf_wren && wdf_mask != 16'hFFFF) begin
//                $display("gpu-TB: ...", x, y);
//            end
            #(Cycle);
        end
        $monitor();
        CNT_SHOW();
        if (gp_fault) ELOG_ERROR("GPCode", "Fault");
        $display("gpu-TB: Done.");
    end endtask


    GPU #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN),
        .WATCH_SLR(WATCH_SLR)
    ) DUT (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //GraphicsProcessor interface:
        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
        .gp_rcode(gp_rcode), .gp_status(gp_status),
        .irq_gp_done(irq_gp_done),
    //DDR FIFOs (read-only for GraphicsProcessor):
        .gcmd_raf_full(gcmd_raf_full),
        .gcmd_raf_wren(gcmd_raf_wren),
        .gcmd_raf_addr(gcmd_raf_addr),
        .gcmd_rdf_rden(gcmd_rdf_rden),
        .gcmd_rdf_wren(gcmd_rdf_wren),
        .gcmd_rdf_data(rdf_data),
    //DDR FIFOs (write-only for ScanLineRunner):
        .slr_waf_full(bpas_waf_full),
        .slr_waf_wren(bpas_waf_wren),
        .slr_waf_addr(bpas_waf_addr),
        .slr_wdf_full(bpas_wdf_full),
        .slr_wdf_wren(bpas_wdf_wren),
        .slr_wdf_mask(bpas_wdf_mask),
        .slr_wdf_data(bpas_wdf_data)
    ) /* synthesis syn_noprune=1 */;


// Fake memory fetch/response, always fetches 2-parts of SAMPLE-1 ignoring address!
    localparam MS_DEAD=0, MS_IDLE=1, MS_OFFER1=2, MS_OFFER2=3;
    reg [1:0] mem_ns, mem_cs = MS_DEAD;
    integer mem_offset;
    always @(*) begin
        mem_ns = mem_cs;  //Default: Hold prior state
        gcmd_raf_full = 1'b1; //Default: Pretend full like RequestController
        gcmd_rdf_wren = 1'b0; //Default: Read value invalid
        rdf_data = 128'bz;//Default: Obvious bad value
        case (mem_cs)
            MS_IDLE: begin
                gcmd_raf_full = 1'b0;
                if (gcmd_raf_wren) mem_ns = MS_OFFER1; //NOTE:IGNORES gcmd_raf_addr!
            end
            MS_OFFER1, MS_OFFER2: begin
                gcmd_rdf_wren = 1'b1; //First/Second 128-bits from SAMPLE
                rdf_data[127:0] = DDR2MEM[mem_offset +: 128];
                if (gcmd_rdf_rden) mem_ns = (mem_cs==MS_OFFER1) ? MS_OFFER2 : MS_IDLE;
            end
            default: mem_ns = MS_DEAD;
        endcase
    end
    always @(posedge cpu_clk_g) begin
        if (rst_cpu_bus) mem_cs <= MS_IDLE;
        else mem_cs <= mem_ns;

        if (gcmd_raf_wren) begin
            //Use blocking assignment (simulation only)!
            if (!gcmd_raf_full) mem_offset = ((gcmd_raf_addr * 64) % 1024);
            $display("MEM-F: full=%b addr=%h offset=%0d",
                     gcmd_raf_full, gcmd_raf_addr, mem_offset
            );
        end
        if (gcmd_rdf_wren || gcmd_rdf_rden) begin
            if (gcmd_rdf_wren && gcmd_rdf_rden) mem_offset = mem_offset + 128;
            $display("MEM-R: wren=%b rden=%b offset=%h offer=%b data=%h.%h.%h.%h",
                gcmd_rdf_wren, gcmd_rdf_rden, mem_offset, (mem_cs==MS_OFFER2),
                rdf_data[127:96], rdf_data[95:64],
                rdf_data[63:32], rdf_data[31:0]
            );
        end
    end

endmodule
