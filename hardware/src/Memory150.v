//----------------------------------------------------------------------
// Module: Memory.v
// Authors: James Parker, Daiwei Li
// This module contains the instantiaton of the Xilinx DDR2 module, the
// clock-crossing FIFOs for communication with the DDR2 controller, and
// the caches.
//
// *** NOTE ***
// You should not need to change the contents of this file. You will,
// however, need to have a general understanding of the FIFO <=> cache
// interface implemented in this module to design the FSM in your cache.
//----------------------------------------------------------------------

module Memory150 #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1, //Order of 32-bit words in each 256-bit DDR block (not byte order)
    parameter SIM_ONLY = 1'b0
)(
// Clocks & Resets:
    input           cpu_clk_g,
    input           dvi_clk_g,
    input           clk0_g,
    input           clkdiv0_g,
    input           clk90_g,
    input           clk200_g,
    input           locked,
    input           rst_cpu_mem,
    output          init_done,
    input           rst_cpu_bus,
    input           rst_dvi_bus,

// DDR2 Interface:
    output  [12:0]  DDR2_A,
    output  [ 1:0]  DDR2_BA,
    output          DDR2_CAS_B,
    output          DDR2_CKE,
    output  [ 1:0]  DDR2_CLK_N,
    output  [ 1:0]  DDR2_CLK_P,
    output          DDR2_CS_B,
    inout   [63:0]  DDR2_D,
    output  [ 7:0]  DDR2_DM,
    inout   [ 7:0]  DDR2_DQS_N,
    inout   [ 7:0]  DDR2_DQS_P,
    output          DDR2_ODT,
    output          DDR2_RAS_B,
    output          DDR2_WE_B,

// Cache <=> CPU Interface:
    input   [31:0]  dcache_addr,
    input   [31:0]  icache_addr,
    input   [ 3:0]  dcache_we,
    input   [ 3:0]  icache_we,
    input           dcache_re,
    input           icache_re,
    input   [31:0]  dcache_din,
    input   [31:0]  icache_din,
    output  [31:0]  dcache_dout,
    output  [31:0]  icache_dout,
    output          stall,
    output          d_stall,
    output          i_stall,

// DVI Interface:
    input           video_ready,
    output          video_valid,
    output  [31:0]  video, //[23:0]

// PixelFeeder <=> CPU Interface:
    output  [15:0]  pf_status,
    input           pf_valid,
    input   [31:0]  pf_frame,
    output          pf_irq,

// GPU/GraphicsProcessor <=> CPU Interface:
    output  [15:0]  gp_status,
    input           gp_valid,
    input   [31:0]  gp_frame, gp_code,
    output          gp_irq
);

    // DDR2 (MIG) interface:
    wire         ddr2_clock_tb;
    wire         ddr2_rst_tb;
    wire         ddr2_caf_afull, ddr2_caf_rden;
    wire         ddr2_wdf_afull, ddr2_wdf_rden;
    wire         ddr2_wdf_valid;
    wire [143:0] ddr2_wdf_maskdata;
    wire         ddr2_rdf_wren, rd_data_valid;
    wire [127:0] ddr2_rd_data;
//  wire         ddr2_caf_empty;
//  wire         ddr2_wdf_empty;
    wire         ddr2_caf_valid;
    wire [ 33:0] ddr2_caf_data;

    // FIFO interface:
    wire         fifo_caf_full;
    wire         fifo_caf_wren;
    wire [  2:0] fifo_caf_cmd;
    wire [ 30:0] fifo_caf_addr;

    wire         fifo_wdf_full;
    wire         fifo_wdf_wren;
    wire [ 15:0] fifo_wdf_mask;
    wire [127:0] fifo_wdf_data;

    wire         fifo_rdf_valid;
    wire         fifo_rdf_rden;
    wire [127:0] fall_rdf_data; //Shared by all


    // Cache <=> RequestController wires:
    wire         inst_caf_full,   data_caf_full;
    wire         inst_caf_wren,   data_caf_wren;
    wire [  2:0] inst_caf_cmd,   data_caf_cmd;
    wire [ 30:0] inst_caf_addr,   data_caf_addr;
    wire         inst_wdf_full,   data_wdf_full;
    wire         inst_wdf_wren,   data_wdf_wren;
    wire [ 15:0] inst_wdf_mask,   data_wdf_mask;
    wire [127:0] inst_wdf_data,   data_wdf_data;
    wire         inst_rdf_valid,  data_rdf_valid;
    wire         inst_rdf_rden,   data_rdf_rden;

    // Read-Only <=> RequestController wires
    //          GraphicsProcessor,  PixelFeeder
    wire         gcmd_rdf_rden;
    wire         gcmd_caf_wren;
    wire [ 30:0] gcmd_caf_addr;
    wire         gcmd_rdf_valid;
    wire         gcmd_caf_full;

    // PixelFeeder <=> RequestController wires:
    wire         pixf_rdf_rden;
    wire         pixf_caf_wren;
    wire [ 30:0] pixf_caf_addr;
    wire         pixf_caf_full;
    wire         pixf_rdf_valid;

    // FrameFiller <=> RequestController wires:
    wire         fill_caf_full;
    wire         fill_wdf_full;
    wire [127:0] fill_wdf_data;
    wire         fill_wdf_wren;
    wire [ 30:0] fill_caf_addr;
    wire         fill_caf_wren;
    wire [ 15:0] fill_wdf_mask;

    // LineEngine <=> RequestController wires:
    wire         line_caf_full;
    wire         line_wdf_full;
    wire [127:0] line_wdf_data;
    wire         line_wdf_wren;
    wire [ 30:0] line_caf_addr;
    wire         line_caf_wren;
    wire [ 15:0] line_wdf_mask;

    // Bypass/ScanLineRunner <=> RequestController wires: (extension!)
    wire         bpas_caf_full;
    wire         bpas_wdf_full;
    wire [127:0] bpas_wdf_data;
    wire         bpas_wdf_wren;
    wire [ 30:0] bpas_caf_addr;
    wire         bpas_caf_wren;
    wire [ 15:0] bpas_wdf_mask;


wire DBG_MEM150 = { //DO NOT mix cross clock-domain signals here with ChipScope!!!
    d_stall, data_wdf_full, data_caf_full, data_rdf_valid,
        1'b0, data_wdf_wren, data_caf_wren, data_rdf_rden,
    i_stall, inst_wdf_full, inst_caf_full, inst_rdf_valid,
        1'b0, inst_wdf_wren, inst_caf_wren, inst_rdf_rden,
    stall, fifo_wdf_full, fifo_caf_full, fifo_rdf_valid,
        1'b0, fifo_wdf_wren, fifo_caf_wren, fifo_rdf_rden,
    1'b0, (fill_caf_full || fill_wdf_full), fill_caf_wren, fill_wdf_wren,
        1'b0, (line_caf_full || line_wdf_full), line_caf_wren, line_wdf_wren
};

//TODO:Try BURST_LEN(8) and/or 266MHz
//TODO:Let MIG generate its own clocks (ideally from differential reference)
   // DDR2 module:
    mig_v3_61 #(
        .SIM_ONLY(SIM_ONLY),
        .CAS_LAT(3), //CAS 3 matches 200MHz (like -53E), CAS 4 matches 266MHz (like -667)
        .BURST_LEN(4),
        .APPDATA_WIDTH(128),
        .CLK_PERIOD(5000), //5000ns==200MHz (3750ns==266MHz, challenging for SpeedGrade-1)
        .RST_ACT_LOW(0) // was 1: flipped this to avoid double inversion
    ) ddr2 (
        .clk0   (clk0_g),
        .clk90  (clk90_g),
        .clkdiv0(clkdiv0_g),
        .clk200 (clk200_g),
        .locked (locked),
        .sys_rst_n(rst_cpu_mem), //was ~rst_cpu_mem (see RST_ACT_LOW parameter)
        .phy_init_done(init_done),

        .clk0_tb(ddr2_clock_tb),
        .rst0_tb(ddr2_rst_tb),

        .ddr2_dq   (DDR2_D),
        .ddr2_a    (DDR2_A),
        .ddr2_ba   (DDR2_BA),
        .ddr2_ras_n(DDR2_RAS_B),
        .ddr2_cas_n(DDR2_CAS_B),
        .ddr2_we_n (DDR2_WE_B),
        .ddr2_cs_n (DDR2_CS_B),
        .ddr2_odt  (DDR2_ODT),
        .ddr2_cke  (DDR2_CKE),
        .ddr2_dm   (DDR2_DM),
        .ddr2_dqs  (DDR2_DQS_P),
        .ddr2_dqs_n(DDR2_DQS_N),
        .ddr2_ck   (DDR2_CLK_P),
        .ddr2_ck_n (DDR2_CLK_N),

        .app_af_afull(ddr2_af_afull),
        .app_af_wren (ddr2_af_wren), //BUG:UNUSED or NAMES BAD or mixed up!
        .app_af_cmd  (ddr2_af_cmd), assign ddr2_af_cmd = ddr2_af_data[33:31]
        .app_af_addr (ddr2_af_addr), assign ddr2_af_addr = ddr2_af_data[30:0]
        .app_wdf_afull    (ddr2_wdf_afull),
        .app_wdf_wren     (ddr2_wdf_wren), assign ddr2_wdf_wren = ddr2_wdf_valid
        .app_wdf_mask_data(ddr2_wdf_mask_data), assign app_wdf_mask_data = ddr2_wdf_maskdata[143:128]
        .app_wdf_data     (ddr2_wdf_data), assign app_wdf_data = ddr2_wdf_maskdata[127:0]
        .rd_data_fifo_out(ddr2_rd_data),
        .rd_data_valid   (ddr2_rd_valid)
    ) /* synthesis syn_noprune=1 */;

    //TODO:Assign all these
    assign ddr2_caf_rden = !ddr2_caf_afull;
    assign ddr2_wdf_rden = !ddr2_wdf_afull;
    assign rd_data_valid = ddr2_rdf_wren;


    // Clock-crossing FIFOs:

    //Cmd/Address Fifo (RCON => DDR2):
    mig_caf ddr2_cadr_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: RCON/CPU clock-domain
        .wr_clk(cpu_clk_g),
        .full  (fifo_caf_full),
        .wr_en (fifo_caf_wren),
        .din   ( {fifo_caf_cmd, fifo_caf_addr} ),
        // FIFO-RD: DDR2 clock-domain
        .rd_clk(ddr2_clock_tb),
        .empty (/*ddr2_caf_empty*/),
        .rd_en (ddr2_caf_rden),
        .valid (ddr2_caf_valid),
        .dout  (ddr2_caf_data)
    ) /* synthesis syn_noprune=1 */;

    //Write-mask/Data Fifo (RCON => DDR2):
    mig_wdf ddr2_mdat_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: RCON/CPU clock-domain
        .wr_clk(cpu_clk_g),
        .full  (fifo_wdf_full),
        .wr_en (fifo_wdf_wren),
        .din   ( {fifo_wdf_mask, fifo_wdf_data} ),
        // FIFO-RD: DDR2 clock-domain
        .rd_clk(ddr2_clock_tb),
        .empty (/*ddr2_wdf_empty*/),
        .rd_en (ddr2_wdf_rden),
        .valid (ddr2_wdf_valid),
        .dout  (ddr2_wdf_maskdata)
    ) /* synthesis syn_noprune=1 */;

    //Read Data Fifo (DDR2 => RCON):
    mig_rdf  ddr2_read_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: DDR2 clock-domain
        .wr_clk(ddr2_clock_tb),
        .full  (),
        .wr_en (),
        .din   (ddr2_rd_data),
        // FIFO-RD: RCON/CPU clock-domain
        .rd_clk(cpu_clk_g),
        .empty (),
        .rd_en (fifo_rdf_rden),
        .valid (xxx),
        .dout  (fall_rdf_data)
    ) /* synthesis syn_noprune=1 */;

    // The RequestController gives each cache the illusion of having
    //   exclusive DDR2 Access:
    RequestController req_con(
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),

        // FIFO inputs:
        .caf_full  (fifo_caf_full),
        .wdf_full (fifo_wdf_full),
        .rdf_valid(fifo_rdf_valid),
        // FIFO outputs:
        .caf_cmd  (fifo_caf_cmd),
        .caf_addr (fifo_caf_addr),
        .caf_wren (fifo_caf_wren),
        .wdf_data(fifo_wdf_data),
        .wdf_mask(fifo_wdf_mask),
        .wdf_wren(fifo_wdf_wren),
        .rdf_rden (fifo_rdf_rden),

        // Data-Cache inputs:             // Inst-Cache inputs:
        .data_caf_full(data_caf_full),    .inst_caf_full(inst_caf_full),
        .data_wdf_full(data_wdf_full),    .inst_wdf_full(inst_wdf_full),
        .data_rdf_valid(data_rdf_valid),   .inst_rdf_valid(inst_rdf_valid),
        // Data-Cache outputs:            // Inst-Cache outputs:
        .data_caf_cmd(data_caf_cmd),     .inst_caf_cmd(inst_caf_cmd),
        .data_caf_addr(data_caf_addr),    .inst_caf_addr(inst_caf_addr),
        .data_caf_wren(data_caf_wren),    .inst_caf_wren(inst_caf_wren),
        .data_wdf_data(data_wdf_data),    .inst_wdf_data(inst_wdf_data),
        .data_wdf_mask(data_wdf_mask),    .inst_wdf_mask(inst_wdf_mask),
        .data_wdf_wren(data_wdf_wren),    .inst_wdf_wren(inst_wdf_wren),
        .data_rdf_rden(data_rdf_rden),    .inst_rdf_rden(inst_rdf_rden),
        .d_stall(d_stall),                .i_stall(i_stall),

// New for cp4-5:
        // PixelFeeder inputs:
        .pixf_caf_wren(pixf_caf_wren),
        .pixf_caf_addr(pixf_caf_addr),
        .pixf_rdf_rden(pixf_rdf_rden),
        // PixelFeeder outputs:
        .pixf_caf_full(pixf_caf_full),
        .pixf_rdf_valid(pixf_rdf_valid),

        // GraphicsProcessor inputs:
        .gcmd_caf_wren(gcmd_caf_wren),
        .gcmd_caf_addr(gcmd_caf_addr),
        .gcmd_rdf_rden(gcmd_rdf_rden),
        // GraphicsProcessor outputs:
        .gcmd_caf_full  (gcmd_caf_full),
        .gcmd_rdf_valid(gcmd_rdf_valid),

        // FrameFiller inputs:
        .fill_caf_addr(fill_caf_addr),
        .fill_caf_wren(fill_caf_wren),
        .fill_wdf_wren(fill_wdf_wren),
        .fill_wdf_mask(fill_wdf_mask),
        .fill_wdf_data(fill_wdf_data),
        // FrameFiller outputs:
        .fill_caf_full(fill_caf_full),
        .fill_wdf_full(fill_wdf_full),

        // LineEngine inputs:
        .line_caf_addr(line_caf_addr),
        .line_caf_wren(line_caf_wren),
        .line_wdf_data(line_wdf_data),
        .line_wdf_mask(line_wdf_mask),
        .line_wdf_wren(line_wdf_wren),
        // LineEngine outputs:
        .line_caf_full(line_caf_full),
        .line_wdf_full(line_wdf_full),

        // Bypass/SLR inputs: //NOTE:XTRA:Extended to allow bypass input
        .bpas_caf_addr(bpas_caf_addr),
        .bpas_caf_wren(bpas_caf_wren),
        .bpas_wdf_data(bpas_wdf_data),
        .bpas_wdf_mask(bpas_wdf_mask),
        .bpas_wdf_wren(bpas_wdf_wren),
        // Bypass/SLR outputs:
        .bpas_caf_full(bpas_caf_full),
        .bpas_wdf_full(bpas_wdf_full)
    ) /* synthesis syn_noprune=1 */;

    // The instruction cache:
    Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) icache (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
        .addr(icache_addr),
        .din(icache_din),
        .we(icache_we),
        .re(icache_re),
        .rdf_valid(inst_rdf_valid),
        .rdf_data(fall_rdf_data),
        .caf_full(inst_caf_full),
        .wdf_full(inst_wdf_full),
        .stall(i_stall),
        .dout(icache_dout),
        .rdf_rden(inst_rdf_rden),
        .caf_cmd(inst_caf_cmd),
        .caf_addr(inst_caf_addr),
        .caf_wren(inst_caf_wren),
        .wdf_data(inst_wdf_data),
        .wdf_mask(inst_wdf_mask),
        .wdf_wren(inst_wdf_wren)
    ) /* synthesis syn_noprune=1 */;

    // Data cache:
    Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) dcache (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
        .addr(dcache_addr),
        .din(dcache_din),
        .we(dcache_we),
        .re(dcache_re),
        .rdf_valid(data_rdf_valid),
        .rdf_data(fall_rdf_data),
        .caf_full(data_caf_full),
        .wdf_full(data_wdf_full),
        .stall(d_stall),
        .dout(dcache_dout),
        .rdf_rden(data_rdf_rden),
        .caf_cmd(data_caf_cmd),
        .caf_addr(data_caf_addr),
        .caf_wren(data_caf_wren),
        .wdf_data(data_wdf_data),
        .wdf_mask(data_wdf_mask),
        .wdf_wren(data_wdf_wren)
    ) /* synthesis syn_noprune=1 */;

    assign stall = d_stall || i_stall;


    // For feeding pixels to the DVI module:
    PixelFeeder #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) pf (
        .cpu_clk_g(cpu_clk_g),
        .cpu_rst_g(rst_cpu_bus),
        .dvi_clk_g(dvi_clk_g),
        .dvi_rst_g(rst_dvi_bus),
    //DDR FIFOs (read-only):
        .caf_full(pixf_caf_full),
        .caf_wren(pixf_caf_wren),
        .caf_addr(pixf_caf_addr),
        .rdf_valid(pixf_rdf_valid),
        .rdf_rden(pixf_rdf_rden),
        .rdf_data(fall_rdf_data),
    // DVI driver:
        .video_ready(video_ready),
        .video_valid(video_valid),
        .video      (video),
    // FRAME control <=> CPU:
        .pf_status(pf_status),
        .pf_frame (pf_frame),
        .pf_valid (pf_valid),
        .pf_irq   (pf_irq)
    ) /* synthesis syn_noprune=1 */;

    //For CP5:
    //GPU holds GraphicsProcessor, ScanLineRunner,
    //  & engines (FrameFiller, LineEngine, ElipseEngine)
    GPU #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) gpu (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //GraphicsProcessor interface:
        .gp_status(gp_status),
        .gp_valid (gp_valid),
        .gp_frame (gp_frame),
        .gp_code  (gp_code),
        .gp_irq   (gp_irq),
    //DDR FIFOs (read-only for GraphicsProcessor):
        .gcmd_caf_wren(gcmd_caf_wren),
        .gcmd_caf_addr(gcmd_caf_addr),
        .gcmd_caf_full(gcmd_caf_full),
        .gcmd_rdf_rden(gcmd_rdf_rden),
        .gcmd_rdf_valid(gcmd_rdf_valid),
        .gcmd_rdf_data(fall_rdf_data),
    //DDR FIFOs (write-only for ScanLineRunner):
        .slr_caf_full(bpas_caf_full),
        .slr_wdf_full(bpas_wdf_full),
        .slr_caf_wren(bpas_caf_wren),
        .slr_caf_addr(bpas_caf_addr),
        .slr_wdf_wren(bpas_wdf_wren),
        .slr_wdf_data(bpas_wdf_data),
        .slr_wdf_mask(bpas_wdf_mask)
    ) /* synthesis syn_noprune=1 */;

endmodule
