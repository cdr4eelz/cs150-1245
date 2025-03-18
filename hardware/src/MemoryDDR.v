//----------------------------------------------------------------------
// Module: Memory.v
// Authors: James Parker, Daiwei Li
// This module contains the instantiaton of the Xilinx DDR3 module, the
// clock-crossing FIFOs for communication with the DDR3 controller, and
// the caches.
//
// *** NOTE ***
// You should not need to change the contents of this file. You will,
// however, need to have a general understanding of the FIFO <=> cache
// interface implemented in this module to design the FSM in your cache.
//----------------------------------------------------------------------


module MemoryDDR #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1 //Order of 32-bit words in each 256-bit DDR block (not byte order)
) (
// Clocks & Resets:
    input           clk_cpu,
    input           clk_pix,
    input           clk_mig_sys,
    input           clk_mig_ref,
    input           rst_cpu_mem,
    input           rst_cpu_bus,
    input           rst_pix,
    input           locked,
    output          init_done,  // init_calib_complete (related to ddr3_reset_n below???)

// DDR3 Pads:
    // DDR3 Inouts
    inout [15:0]    ddr3_dq,        // inout    WAS: DDR2_D[63:0]
    inout [1:0]     ddr3_dqs_n,     // inout    WAS: DDR2_DQS_N[7:0]
    inout [1:0]     ddr3_dqs_p,     // inout    WAS: DDR2_DQS_P[7:0]
    // DDR3 Outputs
    output [13:0]   ddr3_addr,      // output   WAS: [12:0] DDR2_A    *** One bit wider ***
    output [2:0]    ddr3_ba,        // output   WAS: [1:0] DDR2_BA    *** One bit wider ***
    output          ddr3_ras_n,     // output   WAS: DDR2_RAS_B
    output          ddr3_cas_n,     // output   WAS: DDR2_CAS_B
    output          ddr3_we_n,      // output   WAS: DDR2_WE_B
    output [0:0]    ddr3_ck_p,      // output   WAS: [1:0] DDR2_CLK_P
    output [0:0]    ddr3_ck_n,      // output   WAS: [1:0] DDR2_CLK_N
    output [0:0]    ddr3_cke,       // output   WAS: DDR2_CKE0
    output [0:0]    ddr3_cs_n,      // output   WAS: DDR2_CS0_B,
    output [1:0]    ddr3_dm,        // output   WAS: [7:0] DDR2_DM
    output [0:0]    ddr3_odt,       // output   WAS: DDR2_ODT0
    output          ddr3_reset_n,   // ???

// Cache <=> CPU:
    input   [31:0]  dcache_addr,    icache_addr,
    input   [ 3:0]  dcache_we,      icache_we,
    input           dcache_re,      icache_re,
    input   [31:0]  dcache_din,     icache_din,
    output  [31:0]  dcache_dout,    icache_dout,
    output          d_stall,        i_stall,
    output   [3:0]  DBG_dcache,     DBG_icache,  //4-bits, Cache returns 3-bits

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

    wire stall, init_calib_complete;
    assign init_done = init_calib_complete; //Assign rather than renaming
    wire [2:0]  DBG_dcache_cs,  DBG_icache_cs;


//TODO: Check use of "fifo_caf_rdy" vs. old "!fifo_caf_full"
//        Also check "fifo_wdf_rdy" vs. old "!fifo_wdf_full"
//      Seems like current use is okay. It controls a FIFO but doesn't propagate.

// MIG feeds clock/rst back to us (use for clock-crossing FIFOs)
    wire            clk_mig_ui;
    wire            rst_mig_ui;

// FIFOs <=> DDR3/MIG:                      [clk_mig_ui domain]
//  wire            fifo_caf_empty; //FIFO: <Unused>
    wire            fifo_caf_rdy;   //DDR3: "ready"             WAS: !fifo_caf_full
    wire            fifo_caf_wren;  //FIFO: "valid"
    wire [ 30:0]    fifo_caf_cadr;  //FIFO: {cmd-3,addr-28}     NOTE:Width WAS: [33:0]
//  wire            fifo_wdf_empty; //FIFO: <Unused>
    wire            fifo_wdf_rdy;   //DDR3: "ready"             WAS: !fifo_wdf_full
    wire            fifo_wdf_wren;  //FIFO: "valid"
    wire [143:0]    fifo_wdf_mdat;  //FIFO: {mask-16,data-128}  NOTE:Same width
//  wire            fifo_rdf_full;  //FIFO: N/A (always-ready)
    wire            fifo_rdf_wren;  //DDR3: "valid"
    wire [127:0]    fifo_rdf_data;  //DDR3: data                NOTE:Same width

// RequestController/MASTER <=> FIFOs:      [clk_cpu domain]
    wire            rcon_caf_full;  //FIFO: "!ready"
    wire            rcon_caf_wren;  //RCON: "valid"
    wire [ 30:0]    rcon_caf_cadr;  //RCON: {cmd-3,addr-28}     NOTE:Width WAS: [33:0]
    wire            rcon_wdf_full;  //FIFO: "!ready"
    wire            rcon_wdf_wren;  //RCON: "valid"
    wire [143:0]    rcon_wdf_mdat;  //RCON: {mask-16,data-128}  NOTE:Same width
//  wire            rcon_rdf_empty; //FIFO: <Unused>
    wire            rcon_rdf_rden;  //RCON: "ready"
    wire            rcon_rdf_wren;  //FIFO: "valid"
    wire [127:0]    ALLR_rdf_data;  //FIFO: ALL-Readers         NOTE:Same width

    //Inst/Data-Caches <=> RequestController:   [Read-Write]
    wire         inst_caf_full,     data_caf_full;
    wire         inst_caf_wren,     data_caf_wren;
    wire [ 30:0] inst_caf_cadr,     data_caf_cadr; // {cmd-3,addr-28}  WAS: [33:0]
    wire         inst_wdf_full,     data_wdf_full;
    wire         inst_wdf_wren,     data_wdf_wren;
    wire [143:0] inst_wdf_mdat,     data_wdf_mdat; // {mask-16,data-128}
    wire         inst_rdf_rden,     data_rdf_rden;
    wire         inst_rdf_wren,     data_rdf_wren;

    //GraphicsProcessor <=> RequestController:  [Read-only]
    wire         gcmd_raf_full; //RCON:
    wire         gcmd_raf_wren;
    wire [ 27:0] gcmd_raf_addr; //WAS: [30:0]
    wire         gcmd_rdf_rden;
    wire         gcmd_rdf_wren; //RCON:

    //PixelFeeder <=> RequestController:        [Read-only]
    wire         pixf_raf_full; //RCON:
    wire         pixf_raf_wren;
    wire [ 27:0] pixf_raf_addr; // WAS: [30:0]
    wire         pixf_rdf_rden;
    wire         pixf_rdf_wren; //RCON:

    //FrameFiller <=> RequestController:        [Write-only]
    wire         fill_waf_full; //RCON:
    wire         fill_waf_wren  = 1'b0; //Unused (SLR-only)
    wire [ 27:0] fill_waf_addr  = 31'bx; //WAS: [30:0]
    wire         fill_wdf_full; //RCON:
    wire         fill_wdf_wren  = 1'b0;
    wire [ 15:0] fill_wdf_mask  = 16'bx;
    wire [127:0] fill_wdf_data  = 128'bx;
    wire [143:0] fill_wdf_mdat = {fill_wdf_mask,fill_wdf_data};

    //LineEngine <=> RequestController:         [Write-only]
    wire         line_waf_full; //RCON:
    wire         line_waf_wren  = 1'b0; //Unused (SLR-only)
    wire [ 27:0] line_waf_addr  = 28'bx; //WAS: [30:0]
    wire         line_wdf_full; //RCON:
    wire         line_wdf_wren  = 1'b0;
    wire [ 15:0] line_wdf_mask  = 16'bx;
    wire [127:0] line_wdf_data  = 128'bx;
    wire [143:0] line_wdf_mdat = {line_wdf_mask,line_wdf_data};

    //Bypass/SLR <=> RequestController:         [Write-only]
    wire         bpas_waf_full; //RCON:
    wire         bpas_waf_wren;
    wire [ 27:0] bpas_waf_addr; //WAS: [30:0]
    wire         bpas_wdf_full; //RCON:
    wire         bpas_wdf_wren;
    wire [ 15:0] bpas_wdf_mask;
    wire [127:0] bpas_wdf_data;
    wire [143:0] bpas_wdf_mdat = {bpas_wdf_mask,bpas_wdf_data};


    mig_arty_a7_100 u_mig_arty_a7_100 ( // There are no parameters available
        // DDR3 InOuts
        .ddr3_dq                (ddr3_dq),              // inout  [15:0]
        .ddr3_dqs_n             (ddr3_dqs_n),           // inout  [1:0]
        .ddr3_dqs_p             (ddr3_dqs_p),           // inout  [1:0]
        // DDR3 Outputs
        .ddr3_addr              (ddr3_addr),            // output [13:0]
        .ddr3_ba                (ddr3_ba),              // output [2:0]
        .ddr3_ras_n             (ddr3_ras_n),           // output
        .ddr3_cas_n             (ddr3_cas_n),           // output
        .ddr3_we_n              (ddr3_we_n),            // output
        .ddr3_ck_p              (ddr3_ck_p),            // output [0:0]
        .ddr3_ck_n              (ddr3_ck_n),            // output [0:0]
        .ddr3_cke               (ddr3_cke),             // output [0:0]
        .ddr3_cs_n              (ddr3_cs_n),            // output [0:0]
        .ddr3_dm                (ddr3_dm),              // output [1:0]
        .ddr3_odt               (ddr3_odt),             // output [0:0]
        .ddr3_reset_n           (ddr3_reset_n),         // output
        .init_calib_complete    (init_calib_complete),  // output

//DONE: .app_af_addr      (fifo_caf_cadr[30:0])     //DDR2  <= FIFO: address  BECOMES: .app_addr [27:0]
//DONE: .app_af_cmd       (fifo_caf_cadr[33:31])    //DDR2  <= FIFO: command  BECOMES: .app_cmd [30:28]
//DONE: .app_af_afull     (fifo_caf_full),          //DDR2 =>  FIFO: "!ready" BECOMES: .app_rdy(fifo_caf_rdy)
//DONE: .app_af_wren      (fifo_caf_wren),          //DDR2  <= FIFO: "valid"  BECOMES: .app_en
//DONE: .app_wdf_afull    (fifo_wdf_full)           //DDR2 =>  FIFO: "!ready" BECOMES: .app_wdf_rdy(app_wdf_rdy)
//DONE: .app_wdf_wren     (fifo_wdf_wren)           //DDR2  <= FIFO: "valid"  STAYS:   .app_wdf_wren
//DONE: .app_wdf_mask_data(fifo_wdf_mdat[143:128])  //DDR2  <= FIFO: mask     BECOMES: .app_wdf_mask
//DONE: .app_wdf_data     (fifo_wdf_mdat[127:  0])  //DDR2  <= FIFO: data     STAYS:   .app_wdf_data
//DONE: .rd_data_valid    (fifo_rdf_wren)           //DDR2 =>  FIFO: "valid"  BECOMES: .app_rd_data_valid
//DONE: .rd_data_fifo_out (fifo_rdf_data)           //DDR2 =>  FIFO: data     BECOMES: .app_rd_data

        // Application interface ports (NOTE: ADDR_WIDTH=28 CMD_WIDTH=3)
        .app_addr           (fifo_caf_cadr[27:0]),  // input  [27:0]  WAS .app_af_addr [30:0]
      //.app_af_addr(fifo_caf_cadr[30:0]) //DDR2  <= FIFO: address
        .app_cmd            (fifo_caf_cadr[30:28]), // input  [2:0]   WAS .app_af_cmd [33:31]
      //.app_af_cmd(fifo_caf_cadr[33:31]) //DDR2  <= FIFO: command
        .app_en             (fifo_caf_wren),        // input          WAS: .app_af_wren
      //.app_af_wren(fifo_caf_wren) //DDR2   <= FIFO: "valid"
        .app_rdy            (fifo_caf_rdy),         // output         WAS: !.app_af_afull(fifo_caf_full)
      //.app_af_afull(fifo_caf_full) //DDR2  =>  FIFO: "!ready"

        .app_wdf_data       (fifo_wdf_mdat[127:  0]),   // input  [127:0]  STAYS: .app_wdf_data
      //.app_wdf_data(fifo_wdf_mdat[127:0]) //DDR2  <= FIFO: data-128
        .app_wdf_mask       (fifo_wdf_mdat[143:128]),   // input  [15:0]  WAS: .app_wdf_mask_data
      //.app_wdf_mask_data(fifo_wdf_mdat[143:128]) //DDR2 <= FIFO: mask-16
        .app_wdf_wren       (fifo_wdf_wren),    // input  : DDR3  <= FIFO: "valid"  STAYS: .app_wdf_wren
      //.app_wdf_wren(fifo_wdf_wren)        //DDR2  <= FIFO: "valid"
        .app_wdf_rdy        (fifo_wdf_rdy),     // output         WAS: !.app_wdf_afull(fifo_wdf_full)
      //.app_wdf_afull(fifo_wdf_full)       //DDR2 =>  FIFO: "!ready"
        .app_wdf_end        (fifo_wdf_wren),    // input  Obsolete, drive with "wdf_wren"
      //NOTE: The "_end" are obsolete & will be removed in future.

        .app_rd_data        (fifo_rdf_data),    // output [127:0] WAS: .rd_data_fifo_out
      //.rd_data_fifo_out(fifo_rdf_data)    //DDR2 =>  FIFO: data
        .app_rd_data_valid  (fifo_rdf_wren),    // output         WAS: .rd_data_valid
      //.rd_data_valid(fifo_rdf_wren)       //DDR2 =>  FIFO: "valid"
        .app_rd_data_end    ( ),     // output  UNUSED
      //NOTE: The "_end" are depricated & unused, to be removed from MIG

        // Unknown new signals, appearing to have a "request/acknowledge" pattern to them
        .app_sr_req (1'b0), .app_sr_active  ( ), // input / output  UNUSED
        .app_ref_req(1'b0), .app_ref_ack    ( ), // input / output  UNUSED
        .app_zq_req (1'b0), .app_zq_ack     ( ), // input / output  UNUSED

        // System Clock Port (MIG generates various other clocks from this)
        .sys_clk_i          (clk_mig_sys),      // input  Currently 100MHz
        // Reference Clock Port (Always 200MHz, drives "iodelay" lines)app_zq_ack
        .clk_ref_i          (clk_mig_ref),      // input  ALWAYS 200MHz
        // Reset MIG, presumably in ".sys_clk_i" clock domain???
        .sys_rst            (rst_cpu_mem),      // input
        // A clock OUTPUT from MIG to match "UI" or "app" that drives one side of our FIFOs
        .ui_clk             (clk_mig_ui),       // output WAS: .clk0_tb(ddr2_clock_tb)
        .ui_clk_sync_rst    (rst_mig_ui),       // output WAS: .rst0_tb(ddr2_rst_tb)

        .device_temp        ( ) // output [11:0]  UNUSED
    );
    // OLD DDR2 (MIG) module:
/*  mig_v3_61 #(
        .SIM_ONLY(SIM_ONLY),
        .CAS_LAT(3), //CAS 3 matches 200MHz (like -53E), CAS 4 matches 266MHz (like -667)
        .BURST_LEN(4),
        .CLK_PERIOD(5000), //5000ns==200MHz (3750ns==266MHz, challenging for SpeedGrade-1)
        .APPDATA_WIDTH(128),
        .RST_ACT_LOW(0) // was 1: flipped this to avoid double inversion
    ) ddr2 (
        .clk0 (clk0_g), .clk90 (clk90_g), .clkdiv0(clkdiv0_g), .clk200 (clk200_g),
        .locked (locked), .sys_rst_n(rst_cpu_mem), .phy_init_done(init_done),
        .clk0_tb(ddr2_clock_tb), .rst0_tb(ddr2_rst_tb),

        .ddr2_dq(DDR2_D),  .ddr2_a(DDR2_A),  .ddr2_ba(DDR2_BA),  .ddr2_ras_n(DDR2_RAS_B),
        .ddr2_cas_n(DDR2_CAS_B),  .ddr2_we_n(DDR2_WE_B),  .ddr2_cs_n(DDR2_CS_B),
        .ddr2_odt(DDR2_ODT),  .ddr2_cke(DDR2_CKE),  .ddr2_dm(DDR2_DM),  .ddr2_dqs(DDR2_DQS_P),
        .ddr2_dqs_n(DDR2_DQS_N),  .ddr2_ck(DDR2_CLK_P),  .ddr2_ck_n(DDR2_CLK_N),
        .app_af_afull     (fifo_caf_full),          //DDR2 =>  FIFO: "!ready" BECOMES: .app_rdy(fifo_caf_rdy)
        .app_af_wren      (fifo_caf_wren),          //DDR2  <= FIFO: "valid"
        .app_af_cmd       (fifo_caf_cadr[33:31]),   //DDR2  <= FIFO: command  BECOMES: .app_cmd [30:28]
        .app_af_addr      (fifo_caf_cadr[30:0]),    //DDR2  <= FIFO: address  BECOMES: .app_addr [27:0]
        .app_wdf_afull    (fifo_wdf_full),          //DDR2 =>  FIFO: "!ready" BECOMES: .app_wdf_rdy(!fifo_wdf_rdy)
        .app_wdf_wren     (fifo_wdf_wren),          //DDR2  <= FIFO: "valid"
        .app_wdf_mask_data(fifo_wdf_mdat[143:128]), //DDR2  <= FIFO: mask     BECOMES: .app_wdf_mask
        .app_wdf_data     (fifo_wdf_mdat[127:  0]), //DDR2  <= FIFO: data
                                                    //DDR2  <= FIFO: always-ready
        .rd_data_valid    (fifo_rdf_wren),          //DDR2 =>  FIFO: "valid"  BECOMES: .app_rd_data_valid
        .rd_data_fifo_out (fifo_rdf_data)           //DDR2 =>  FIFO: data     BECOMES: .app_rd_data
    ); */

// Clock-crossing FIFOs (RCON[clk_cpu] <=> FIFOs <=> MIG[clk_mig_ui]):
    //{Command,Address} Fifo (RCON => FIFO => DDR3-MIG)...
    mig_caf ddr3_cadr_fifo (
        .rst    (rst_mig_ui),       // input    : NOT rst_cpu_bus?
    // FIFO-WR: RCON clock-domain
        .wr_clk (clk_cpu),          // input    : CPU/RCON clock
        .full   (rcon_caf_full),    // output   : FIFO =>  RCON: "!ready"
        .wr_en  (rcon_caf_wren),    // input    : FIFO  <= RCON: "valid"
        .din    (rcon_caf_cadr),  //input[30:0] : FIFO  <= RCON: {cmd-3,addr-28} = 31
    // FIFO-RD: DDR3 clock-domain
        .rd_clk (clk_mig_ui),       // input    : MIG sys_clk_i clock
        .empty  ( ), // output : <Unused> (fifo_caf_empty)
        .rd_en  (fifo_caf_rdy),     // input    : FIFO  <= DDR3: "ready"  WAS: !fifo_caf_full
        .valid  (fifo_caf_wren),    // output   : FIFO =>  DDR3: "valid"
        .dout   (fifo_caf_cadr)  //output[30:0] : FIFO =>  DDR3: {cmd-3,addr-28} = 31
    );

    //Write-mask/Data Fifo (RCON => FIFO => DDR3-MIG)...
    mig_wdf ddr3_mdat_fifo (
        .rst    (rst_mig_ui),       // input    : NOT rst_cpu_bus?
        // FIFO-WR: RCON clock-domain
        .wr_clk (clk_cpu),          // input    : CPU/RCON clock
        .full   (rcon_wdf_full),    // output   : FIFO =>  RCON: "!ready"
        .wr_en  (rcon_wdf_wren),    // input    : FIFO  <= RCON: "valid"
        .din    (rcon_wdf_mdat), //input[143:0] : FIFO  <= RCON: {mask-16,data-128} = 144
        // FIFO-RD: DDR3 clock-domain
        .rd_clk (clk_mig_ui),       // input    : MIG sys_clk_i clock
        .empty  ( ), // output : <Unused> (fifo_wdf_empty)
        .rd_en  (fifo_wdf_rdy),     // input    : FIFO  <= DDR3: "ready"  WAS: !fifo_wdf_full
        .valid  (fifo_wdf_wren),    // output   : FIFO =>  DDR3: "valid"
        .dout   (fifo_wdf_mdat) //output[143:0] : FIFO =>  DDR3: {mask-16,data-128} = 144
    );

    //Read Data Fifo (DDR3 => FIFO => RCON):
    mig_rdf  ddr3_read_fifo (
        .rst(rst_mig_ui),           // input    : NOT rst_cpu_bus?
        // FIFO-WR: DDR3 clock-domain
        .wr_clk(clk_mig_ui),        // input    : MIG sys_clk_i
        .full  ( ), // output   : FIFO =>  DDR3: N/A (always ready) fifo_rdf_full
        .wr_en (fifo_rdf_wren),     // input    : FIFO  <= DDR3: "ready"
        .din   (fifo_rdf_data),  //input[127:0] : FIFO  <= DDR3: data-128
        // FIFO-RD: RCON clock-domain
        .rd_clk(clk_cpu),           // input    : CPU/RCON clock
        .empty ( ), // output  : <Unused>  rcon_rdf_empty
        .rd_en (rcon_rdf_rden),     // input    : FIFO  <= RCON: "ready"
        .valid (rcon_rdf_wren),     // output   : FIFO =>  RCON: "valid"
        .dout  (ALLR_rdf_data)  //output[127:0] : FIFO => ALL-Readers (direct) data-128
    );

    // The RequestController gives each cache the illusion of having
    //   exclusive DDR3 Access:
/*    RequestController rcon (
        .clk(clk_cpu),
        .rst(rst_cpu_bus),  //MAYBE: rst_cpu_mem???
    // Master/RequestController interface:

//        .caf_full(rcon_caf_full),   //input  RCON  <= FIFO  : "!ready"
//        .caf_wren(rcon_caf_wren),   //RCON =>  FIFO         : "valid"
//        .caf_cadr(rcon_caf_cadr),   //RCON =>  FIFO         : {cmd,addr}
//        .wdf_full(rcon_wdf_full),   //input  RCON  <= FIFO  : "!ready"
//        .wdf_wren(rcon_wdf_wren),   //RCON =>  FIFO         : "valid"
//        .wdf_mdat(rcon_wdf_mdat),   //RCON =>  FIFO         : {mask,data}
//        .rdf_rden(rcon_rdf_rden),   //RCON =>  FIFO         : "ready" (ignored?)
//        .rdf_wren(rcon_rdf_wren),   //input  RCON  <= FIFO  : "valid"

        .caf_full(1'b1),   //input  RCON  <= FIFO  : "!ready"
        .caf_wren( ),   //RCON =>  FIFO         : "valid"
        .caf_cadr( ),   //RCON =>  FIFO         : {cmd,addr}
        .wdf_full(1'b1),   //input  RCON  <= FIFO  : "!ready"
        .wdf_wren( ),   //RCON =>  FIFO         : "valid"
        .wdf_mdat( ),   //RCON =>  FIFO         : {mask,data}
        .rdf_rden( ),   //RCON =>  FIFO         : "ready" (ignored?)
        .rdf_wren(1'b0),   //input  RCON  <= FIFO  : "valid"

    // Read/Write/Stall interfaces:
        //Data-Cache interface:         //Inst-Cache interface:
        .data_caf_full(data_caf_full),  .inst_caf_full(inst_caf_full), //OUT
        .data_caf_wren(data_caf_wren),  .inst_caf_wren(inst_caf_wren), //IN
        .data_caf_cadr(data_caf_cadr),  .inst_caf_cadr(inst_caf_cadr), //IN [30:0] {cmd-3,addr-28}
        .data_wdf_full(data_wdf_full),  .inst_wdf_full(inst_wdf_full), //OUT
        .data_wdf_wren(data_wdf_wren),  .inst_wdf_wren(inst_wdf_wren), //IN
        .data_wdf_mdat(data_wdf_mdat),  .inst_wdf_mdat(inst_wdf_mdat), //IN {mask-16,data-128}
        .data_rdf_rden(data_rdf_rden),  .inst_rdf_rden(inst_rdf_rden), //IN
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
        //Bypass/SLR interface:
        .bpas_waf_full(bpas_waf_full), //OUT
        .bpas_waf_wren(bpas_waf_wren),
        .bpas_waf_addr(bpas_waf_addr),
        .bpas_wdf_full(bpas_wdf_full), //OUT
        .bpas_wdf_wren(bpas_wdf_wren),
        .bpas_wdf_mdat(bpas_wdf_mdat)
    );
*/
    // The instruction cache:
/*  Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) icache (
        .clk(clk_cpu),
        .rst(rst_cpu_bus),
        // <= Cache Client (CPU)
        .addr   (icache_addr),
        .din    (icache_din),
        .we     (icache_we),
        .re     (icache_re),
        // <= RequestController
        .caf_full   (inst_caf_full),
        .wdf_full   (inst_wdf_full),
        .rdf_wren   (inst_rdf_wren),
        .rdf_data   (ALLR_rdf_data),
        // => Cache Client (CPU)
        .stall  (i_stall),
        .dout   (icache_dout),
        // => RequestController
        .rdf_rden   (inst_rdf_rden),   // IN
        .caf_cadr   (inst_caf_cadr),   // {cmd-3,addr-28}
        .caf_wren   (inst_caf_wren),
        .wdf_mdat   (inst_wdf_mdat),   // {mask-16,data-128}
        .wdf_wren   (inst_wdf_wren),
        //Unused in this project
        .tag_hit(), .tag_valid(),
        .DBG_cache_cs(DBG_icache_cs)
    );
*/
    // Data cache:
    Cache #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) dcache (
        .clk(clk_cpu),
        .rst(rst_cpu_bus),
        // <= Cache Client (CPU)
        .addr   (dcache_addr),
        .din    (dcache_din),
        .we     (dcache_we),
        .re     (dcache_re),
        // <= RequestController
        .caf_full   (data_caf_full),
        .wdf_full   (data_wdf_full),
        .rdf_wren   (data_rdf_wren),
        .rdf_data   (ALLR_rdf_data),
        // => Cache Client (CPU)
        .stall  (d_stall),
        .dout   (dcache_dout),
        // => RequestController
        .rdf_rden   (data_rdf_rden),
        .caf_cadr   (data_caf_cadr),
        .caf_wren   (data_caf_wren),
        .wdf_mdat   (data_wdf_mdat),
        .wdf_wren   (data_wdf_wren),
        //Unused in this project
        .tag_hit(), .tag_valid(),
        .DBG_cache_cs(DBG_dcache_cs)
    );

    assign stall = d_stall; // || i_stall;
    assign DBG_dcache = { d_stall, DBG_dcache_cs };
    assign DBG_icache = 4'b0000; //{ inst_rdf_wren, DBG_icache_cs };

    assign video_valid = 1'b1;
    assign video       = 32'h00_80_80_FF;

    assign pf_status = 16'd0;
    assign irq_pf_frame = 1'b0;
    assign gp_rcode = 32'd0;
    assign gp_status = 16'd0;
    assign irq_gp_done = 1'b0;

    // For feeding pixels to the DVI module:
/*    PixelFeeder #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) pf (
        .cpu_clk_g(clk_cpu),
        .cpu_rst_g(rst_cpu_bus),
        .dvi_clk_g(clk_pix),
        .dvi_rst_g(rst_pix),
    //DDR FIFOs (read-only):
        .raf_full(pixf_raf_full),
        .raf_wren(pixf_raf_wren), //OUT
        .raf_addr(pixf_raf_addr), //OUT
        .rdf_wren(pixf_rdf_wren), //OUT
        .rdf_rden(pixf_rdf_rden),
        .rdf_data(ALLR_rdf_data),
    // DVI driver:
        .video_ready(video_ready),
        .video_valid(video_valid), //OUT
        .video      (video), //OUT
    // FRAME control <=> CPU:
        .pf_vframe(pf_vframe),
        .pf_wframe(pf_wframe),
        .pf_status(pf_status), //OUT
        .irq_frame(irq_pf_frame) //OUT
    );
*/
/*  GPU #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) gpu (
        .clk(clk_cpu),
        .rst(rst_cpu_bus),
    //GraphicsProcessor interface:
        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe), //IN
        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe), //IN[31:0]
        .gp_rcode(gp_rcode), //OUT[31:0]
        .gp_status(gp_status), //OUT[15:0]
        .irq_gp_done(irq_gp_done), //OUT
    //DDR FIFOs (read-only for GraphicsProcessor):
        .gcmd_raf_full(gcmd_raf_full), //IN
        .gcmd_raf_wren(gcmd_raf_wren), //OUT
        .gcmd_raf_addr(gcmd_raf_addr), //OUT[27:0]
        .gcmd_rdf_rden(gcmd_rdf_rden), //OUT
        .gcmd_rdf_wren(gcmd_rdf_wren), //IN
        .gcmd_rdf_data(ALLR_rdf_data), //IN[127:0]
    //DDR FIFOs (write-only for ScanLineRunner):
        .slr_waf_full(bpas_waf_full), //IN
        .slr_waf_wren(bpas_waf_wren), //OUT
        .slr_waf_addr(bpas_waf_addr), //OUT[15:0]
        .slr_wdf_full(bpas_wdf_full), //IN
        .slr_wdf_wren(bpas_wdf_wren), //OUT
        .slr_wdf_mask(bpas_wdf_mask), //OUT[15:0]
        .slr_wdf_data(bpas_wdf_data)  //OUT[127:0]
    );
*/


/*  // This memory intercepts dcache & icache before RCON & MIG
    big_mem fake_cache_mem (  // Can substitute for actual DDR
        .clka   (clk_cpu),              // input
        .ena    (1'b1),                 // input
        .wea    (dcache_we),            // input    [ 3 : 0]
        .addra  (dcache_addr[16:2]),    // input    [14 : 0]
        .dina   (dcache_din),           // input    [31 : 0]
        .douta  (dcache_dout),          // output   [31 : 0]
        .clkb   (clk_cpu),              // input
        .enb    (1'b1),                 // input
        .web    (icache_we),            // input    [ 3 : 0]
        .addrb  (icache_addr[16:2]),    // input    [14 : 0]
        .dinb   (icache_din),           // input    [31 : 0]
        .doutb  (icache_dout)           // output   [31 : 0]
    ); */

    // Patch DataCache directly with FIFOs (like RCON)
    assign  data_caf_full   = rcon_caf_full,
            data_wdf_full   = rcon_wdf_full,
            data_rdf_wren   = rcon_rdf_wren;
    assign  rcon_rdf_rden   = data_rdf_rden,
            rcon_caf_wren   = data_caf_wren,
            rcon_caf_cadr   = data_caf_cadr,
            rcon_wdf_wren   = data_wdf_wren,
            rcon_wdf_mdat   = data_wdf_mdat;

endmodule
