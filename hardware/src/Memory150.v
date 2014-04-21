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

// DDR2 Pads:
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

// Cache <=> CPU:
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

// PixelFeeder <=> DVI Controller:
    input           video_ready,
    output          video_valid,
    output  [31: 0] video, //[23:0]

// GPU <=> CPU:
    input           pf_vframe,    gp_vcode, gp_vframe,
    input   [31: 0] pf_wframe,    gp_wcode, gp_wframe,
    output  [31: 0]               gp_rcode,
    output  [15: 0] pf_status,              gp_status,
    output          irq_pf_frame, irq_gp_done
);

// DDR2 (MIG) <=> Clock-Crossing FIFOs (clk0_g domain):
    wire         ddr2_clock_tb;
    wire         ddr2_rst_tb;
//  wire         ddr2_caf_empty; //FIFO: <Unused>
    wire         ddr2_caf_full; //DDR2: "!ready"
    wire         ddr2_caf_wren; //FIFO: "valid"
    wire [ 33:0] ddr2_caf_cadr; //FIFO: {cmd,addr}
//  wire         ddr2_wdf_empty; //FIFO: <Unused>
    wire         ddr2_wdf_full; //DDR2: "!ready"
    wire         ddr2_wdf_wren; //FIFO: "valid"
    wire [143:0] ddr2_wdf_mdat; //FIFO: {mask,data}
//  wire         ddr2_rdf_full; //FIFO: N/A (always-ready)
    wire         ddr2_rdf_wren; //DDR2: "valid"
    wire [127:0] ddr2_rdf_data; //DDR2: data

// FIFOs <=> MASTER/RequestController (cpu_clk_g domain):
    wire         fifo_caf_full; //FIFO: "!ready"
    wire         fifo_caf_wren; //RCON: "valid"
    wire [ 33:0] fifo_caf_cadr; //RCON: {cmd,addr}
    wire         fifo_wdf_full; //FIFO: "!ready"
    wire         fifo_wdf_wren; //RCON: "valid"
    wire [143:0] fifo_wdf_mdat; //RCON: {mask,data}
//  wire         fifo_rdf_empty; //FIFO: <Unused>
    wire         fifo_rdf_rden; //RCON: "ready"
    wire         fifo_rdf_wren; //FIFO: "valid"
    wire [127:0] ALLR_rdf_data; //FIFO: data to ALL-Readers

// RequestController <=> Read-Write channels

    //Caches <=> RequestController :
    wire         inst_caf_full,   data_caf_full;
    wire         inst_caf_wren,   data_caf_wren;
    wire [ 33:0] inst_caf_cadr,   data_caf_cadr;
    wire         inst_wdf_full,   data_wdf_full;
    wire         inst_wdf_wren,   data_wdf_wren;
    wire [143:0] inst_wdf_mdat,   data_wdf_mdat;
    wire         inst_rdf_rden,   data_rdf_rden;
    wire         inst_rdf_wren,   data_rdf_wren;

// RequestController <=> Read-only channels

    //GraphicsProcessor <=> RequestController:
    wire         gcmd_raf_full;
    wire         gcmd_raf_wren;
    wire [ 30:0] gcmd_raf_addr;
    wire         gcmd_rdf_rden;
    wire         gcmd_rdf_wren;

    //PixelFeeder <=> RequestController:
    wire         pixf_raf_full;
    wire         pixf_raf_wren;
    wire [ 30:0] pixf_raf_addr;
    wire         pixf_rdf_rden;
    wire         pixf_rdf_wren;

// RequestController <=> Write-only channels

    //FrameFiller <=> RequestController:
    wire         fill_waf_full;
    wire         fill_waf_wren;
    wire [ 30:0] fill_waf_addr;
    wire         fill_wdf_full;
    wire         fill_wdf_wren;
    wire [ 15:0] fill_wdf_mask;
    wire [127:0] fill_wdf_data;
    wire [143:0] fill_wdf_mdat = {fill_wdf_mask,fill_wdf_data};

    //LineEngine <=> RequestController:
    wire         line_waf_full;
    wire         line_waf_wren;
    wire [ 30:0] line_waf_addr;
    wire         line_wdf_full;
    wire         line_wdf_wren;
    wire [ 15:0] line_wdf_mask;
    wire [127:0] line_wdf_data;
    wire [143:0] line_wdf_mdat = {line_wdf_mask,line_wdf_data};

    //Bypass/ScanLineRunner <=> RequestController:
    wire         bpas_waf_full;
    wire         bpas_waf_wren;
    wire [ 30:0] bpas_waf_addr;
    wire         bpas_wdf_full;
    wire         bpas_wdf_wren;
    wire [ 15:0] bpas_wdf_mask;
    wire [127:0] bpas_wdf_data;
    wire [143:0] bpas_wdf_mdat = {bpas_wdf_mask,bpas_wdf_data};

wire DBG_MEM150 = { //DO NOT mix cross clock-domain signals here with ChipScope!!!
    d_stall, data_wdf_full, data_caf_full, data_rdf_wren,
        1'b0, data_wdf_wren, data_caf_wren, data_rdf_rden,
    i_stall, inst_wdf_full, inst_caf_full, inst_rdf_wren,
        1'b0, inst_wdf_wren, inst_caf_wren, inst_rdf_rden
/*    stall, fifo_wdf_full, fifo_caf_full, fifo_rdf_wren,
        1'b0, fifo_wdf_wren, fifo_caf_wren, fifo_rdf_rden,
    1'b0, (fill_caf_full || fill_wdf_full), fill_caf_wren, fill_wdf_wren,
        1'b0, (line_caf_full || line_wdf_full), line_caf_wren, line_wdf_wren
*/ };


    // DDR2 (MIG) module:
    mig_v3_61 #(
        .SIM_ONLY(SIM_ONLY),
        .CAS_LAT(3), //CAS 3 matches 200MHz (like -53E), CAS 4 matches 266MHz (like -667)
        .BURST_LEN(4),
//TODO:Try BURST_LEN(8) and/or 266MHz
//TODO:Let MIG generate its own clocks (ideally from differential reference)
        .CLK_PERIOD(5000), //5000ns==200MHz (3750ns==266MHz, challenging for SpeedGrade-1)
        .APPDATA_WIDTH(128),
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

        .app_af_afull     (ddr2_caf_full),          //DDR2 =>  FIFO: "!ready"
        .app_af_wren      (ddr2_caf_wren),          //DDR2  <= FIFO: "valid"
        .app_af_cmd       (ddr2_caf_cadr[33:31]),   //DDR2  <= FIFO: command
        .app_af_addr      (ddr2_caf_cadr[30:0]),    //DDR2  <= FIFO: address

        .app_wdf_afull    (ddr2_wdf_full),          //DDR2 =>  FIFO: "!ready"
        .app_wdf_wren     (ddr2_wdf_wren),          //DDR2  <= FIFO: "valid"
        .app_wdf_mask_data(ddr2_wdf_mdat[143:128]), //DDR2  <= FIFO: mask
        .app_wdf_data     (ddr2_wdf_mdat[127:  0]), //DDR2  <= FIFO: data

                                                    //DDR2  <= FIFO: always-ready
        .rd_data_valid    (ddr2_rdf_wren),          //DDR2 =>  FIFO: "valid"
        .rd_data_fifo_out (ddr2_rdf_data)           //DDR2 =>  FIFO: data
    ) /* synthesis syn_noprune=1 */;


// Clock-crossing FIFOs ([cpu_clk_g] <=> FIFOs <=> [clk0_g]):

    //{Command,Address} Fifo (RCON => FIFO => DDR2):
    mig_caf ddr2_cadr_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: RCON clock-domain
        .wr_clk(cpu_clk_g),
        .full  (fifo_caf_full),     //FIFO =>  RCON: "!ready"
        .wr_en (fifo_caf_wren),     //FIFO  <= RCON: "valid"
        .din   (fifo_caf_cadr),     //FIFO  <= RCON: {cmd,addr}
        // FIFO-RD: DDR2 clock-domain
        .rd_clk(ddr2_clock_tb),
        .empty (/*ddr2_caf_empty*/), //<Unused>
        .rd_en (!ddr2_caf_full),    //FIFO  <= DDR2: "ready"
        .valid (ddr2_caf_wren),     //FIFO =>  DDR2: "valid"
        .dout  (ddr2_caf_cadr)      //FIFO =>  DDR2: {cmd,addr}
    ) /* synthesis syn_noprune=1 */;

    //Write-mask/Data Fifo (RCON => FIFO => DDR2):
    mig_wdf ddr2_mdat_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: RCON clock-domain
        .wr_clk(cpu_clk_g),
        .full  (fifo_wdf_full),     //FIFO =>  RCON: "!ready"
        .wr_en (fifo_wdf_wren),     //FIFO  <= RCON: "valid"
        .din   (fifo_wdf_mdat),     //FIFO  <= RCON: {mask,data}
        // FIFO-RD: DDR2 clock-domain
        .rd_clk(ddr2_clock_tb),
        .empty (/*ddr2_wdf_empty*/), //<Unused>
        .rd_en (!ddr2_wdf_full),    //FIFO  <= DDR2: "ready"
        .valid (ddr2_wdf_wren),     //FIFO =>  DDR2: "valid"
        .dout  (ddr2_wdf_mdat)      //FIFO =>  DDR2: {mask,data}
    ) /* synthesis syn_noprune=1 */;

    //Read Data Fifo (DDR2 => FIFO => RCON):
    mig_rdf  ddr2_read_fifo (
        .rst(rst_cpu_bus),
        // FIFO-WR: DDR2 clock-domain
        .wr_clk(ddr2_clock_tb),
        .full  (/*ddr2_rdf_full*/), //FIFO =>  DDR2: N/A (always ready)
        .wr_en (ddr2_rdf_wren),     //FIFO  <= DDR2: "ready"
        .din   (ddr2_rdf_data),     //FIFO  <= DDR2: data
        // FIFO-RD: RCON clock-domain
        .rd_clk(cpu_clk_g),
        .empty (/*fifo_rdf_empty*/), //<Unused>
        .rd_en (fifo_rdf_rden),     //FIFO  <= RCON: "ready"
        .valid (fifo_rdf_wren),     //FIFO =>  RCON: "valid"
        .dout  (ALLR_rdf_data)      //FIFO => ALL-Readers (direct)
    ) /* synthesis syn_noprune=1 */;


    // The RequestController gives each cache the illusion of having
    //   exclusive DDR2 Access:
    RequestController rcon (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    // Master/RequestController interface:
        .caf_full(fifo_caf_full), //RCON  <= FIFO: "!ready"
        .caf_wren(fifo_caf_wren), //RCON =>  FIFO: "valid"
        .caf_cadr(fifo_caf_cadr), //RCON =>  FIFO: {cmd,addr}
        .wdf_full(fifo_wdf_full), //RCON  <= FIFO: "!ready"
        .wdf_wren(fifo_wdf_wren), //RCON =>  FIFO: "valid"
        .wdf_mdat(fifo_wdf_mdat), //RCON =>  FIFO: {mask,data}
        .rdf_rden(fifo_rdf_rden), //RCON =>  FIFO: "ready" (ignored?)
        .rdf_wren(fifo_rdf_wren), //RCON  <= FIFO: "valid"
    // Read/Write/Stall interfaces:
        //Data-Cache interface:         //Inst-Cache interface:
        .data_caf_full(data_caf_full),  .inst_caf_full(inst_caf_full), //OUT
        .data_caf_wren(data_caf_wren),  .inst_caf_wren(inst_caf_wren),
        .data_caf_cadr(data_caf_cadr),  .inst_caf_cadr(inst_caf_cadr),
        .data_wdf_full(data_wdf_full),  .inst_wdf_full(inst_wdf_full), //OUT
        .data_wdf_wren(data_wdf_wren),  .inst_wdf_wren(inst_wdf_wren),
        .data_wdf_mdat(data_wdf_mdat),  .inst_wdf_mdat(inst_wdf_mdat),
        .data_rdf_rden(data_rdf_rden),  .inst_rdf_rden(inst_rdf_rden),
        .data_rdf_wren(data_rdf_wren),  .inst_rdf_wren(inst_rdf_wren), //OUT
        .data_stall(d_stall),           .inst_stall(i_stall),
// New for cp4-5:
    //Read-only interfaces:
        //GraphicsProcessor inputs:
        .gcmd_raf_full(gcmd_raf_full), //OUT
        .gcmd_raf_wren(gcmd_raf_wren),
        .gcmd_raf_addr(gcmd_raf_addr),
        .gcmd_rdf_rden(gcmd_rdf_rden),
        .gcmd_rdf_wren(gcmd_rdf_wren), //OUT
        //PixelFeeder interface:
        .pixf_raf_full(pixf_raf_full), //OUT
        .pixf_raf_wren(pixf_raf_wren),
        .pixf_raf_addr(pixf_raf_addr),
        .pixf_rdf_rden(pixf_rdf_rden),
        .pixf_rdf_wren(pixf_rdf_wren), //OUT
    //Write-only interfaces:
        //FrameFiller interface:
        .fill_waf_full(fill_waf_full), //OUT
        .fill_waf_wren(fill_waf_wren),
        .fill_waf_addr(fill_waf_addr),
        .fill_wdf_full(fill_wdf_full), //OUT
        .fill_wdf_wren(fill_wdf_wren),
        .fill_wdf_mdat(fill_wdf_mdat),
        //LineEngine interface:
        .line_waf_full(line_waf_full), //OUT
        .line_waf_wren(line_waf_wren),
        .line_waf_addr(line_waf_addr),
        .line_wdf_full(line_wdf_full), //OUT
        .line_wdf_wren(line_wdf_wren),
        .line_wdf_mdat(line_wdf_mdat),
//NOTE:XTRA:Re-enabled bypass write-only channel
        //Bypass/SLR interface:
        .bpas_waf_full(bpas_waf_full), //OUT
        .bpas_waf_wren(bpas_waf_wren),
        .bpas_waf_addr(bpas_waf_addr),
        .bpas_wdf_full(bpas_wdf_full), //OUT
        .bpas_wdf_wren(bpas_wdf_wren),
        .bpas_wdf_mdat(bpas_wdf_mdat)
    ) /* synthesis syn_noprune=1 */;

    // The instruction cache:
    Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) icache (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
        // <= Cache Client (CPU)
        .addr(icache_addr),
        .din (icache_din),
        .we  (icache_we),
        .re  (icache_re),
        // <= RequestController
        .caf_full(inst_caf_full),
        .wdf_full(inst_wdf_full),
        .rdf_wren(inst_rdf_wren),
        .rdf_data(ALLR_rdf_data),
        // => Cache Client (CPU)
        .stall(i_stall),
        .dout (icache_dout),
        // => RequestController
        .rdf_rden(inst_rdf_rden),
        .caf_cadr(inst_caf_cadr),
        .caf_wren(inst_caf_wren),
        .wdf_mdat(inst_wdf_mdat),
        .wdf_wren(inst_wdf_wren),
        //Unused in this project
        .tag_hit(), .tag_valid(), .state()
    ) /* synthesis syn_noprune=1 */;

    // Data cache:
    Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) dcache (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
        // <= Cache Client (CPU)
        .addr(dcache_addr),
        .din (dcache_din),
        .we  (dcache_we),
        .re  (dcache_re),
        // <= RequestController
        .caf_full(data_caf_full),
        .wdf_full(data_wdf_full),
        .rdf_wren(data_rdf_wren),
        .rdf_data(ALLR_rdf_data),
        // => Cache Client (CPU)
        .stall(d_stall),
        .dout (dcache_dout),
        // => RequestController
        .rdf_rden(data_rdf_rden),
        .caf_cadr(data_caf_cadr),
        .caf_wren(data_caf_wren),
        .wdf_mdat(data_wdf_mdat),
        .wdf_wren(data_wdf_wren),
        //Unused in this project
        .tag_hit(), .tag_valid(), .state()
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
        .raf_full(pixf_raf_full),
        .raf_wren(pixf_raf_wren),
        .raf_addr(pixf_raf_addr),
        .rdf_wren(pixf_rdf_wren),
        .rdf_rden(pixf_rdf_rden),
        .rdf_data(ALLR_rdf_data),
    // DVI driver:
        .video_ready(video_ready),
        .video_valid(video_valid),
        .video      (video),
    // FRAME control <=> CPU:
        .pf_vframe(pf_vframe),
        .pf_wframe(pf_wframe),
        .pf_status(pf_status),
        .irq_frame(irq_pf_frame)
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
        .gcmd_rdf_data(ALLR_rdf_data),
    //DDR FIFOs (write-only for ScanLineRunner):
        .slr_waf_full(bpas_waf_full),
        .slr_waf_wren(bpas_waf_wren),
        .slr_waf_addr(bpas_waf_addr),
        .slr_wdf_full(bpas_wdf_full),
        .slr_wdf_wren(bpas_wdf_wren),
        .slr_wdf_mask(bpas_wdf_mask),
        .slr_wdf_data(bpas_wdf_data)
    ) /* synthesis syn_noprune=1 */;

endmodule
