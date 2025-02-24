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

module MemoryDDR #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1, //Order of 32-bit words in each 256-bit DDR block (not byte order)
    parameter SIM_ONLY = 1'b0
) (
// Clocks & Resets:
    input           clk_cpu,
    input           clk_pix,
    input           clk_mig,
    input           clk_mig_ref,
    input           rst_cpu_mem,
    input           rst_cpu_bus,
    input           rst_pix,
    input           locked,
    output          init_done,
/*
// DDR3 Pads:
    output  [15:0]  ddr3_dq,
    output  [13:0]  ddr3_addr,
    output  [ 2:0]  ddr3_ba,
    output          ddr3_cas_n,
    output  [ 0:0]  ddr3_ck_n,
    output  [ 0:0]  ddr3_ck_p,
    output  [ 1:0]  ddr3_dm,
    inout   [ 1:0]  ddr3_dqs_n,
    inout   [ 1:0]  ddr3_dqs_p,
    output          ddr3_odt,
    output          ddr3_ras_n,
    output          ddr3_we_n,
    ddr3_reset_n,
    ddr3_cke
    ddr3_cs_n
    output          DDR2_CS_B,
    inout   [63:0]  DDR2_D,
    output          DDR2_CKE,
*/
// Cache <=> CPU:
    input   [31:0]  dcache_addr,    icache_addr,
    input   [ 3:0]  dcache_we,      icache_we,
    input           dcache_re,      icache_re,
    input   [31:0]  dcache_din,     icache_din,
    output  [31:0]  dcache_dout,    icache_dout,
    output          d_stall,        i_stall,

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

    wire stall;
    reg init_r = 0;
    always @(posedge clk_cpu)  init_r <= locked;
    assign init_done = init_r;

    //assign dcache_dout = 32'd0; //output  [31:0]  dcache_dout,
    //assign icache_dout = 32'd0; //output  [31:0]  icache_dout,
    assign d_stall = 1'b0;
    assign i_stall = 1'b0;
    assign stall = d_stall || i_stall;

    assign video_valid = 1'b1;
    assign video       = 32'h00_80_80_FF;

    assign gp_rcode = 32'd0;
    assign pf_status = 16'd0;
    assign gp_status = 16'd0;
    assign irq_pf_frame = 1'b0;
    assign irq_gp_done = 1'b0;

    big_mem fake_cache_mem (
        .clka(clk_cpu),    // input wire clka
        .ena(1'b1),      // input wire ena
        .wea(dcache_we),      // input wire [3 : 0] wea
        .addra(dcache_addr[18:2]),  // input wire [16 : 0] addra
        .dina(dcache_din),    // input wire [31 : 0] dina
        .douta(dcache_dout),  // output wire [31 : 0] douta
        .clkb(clk_cpu),    // input wire clkb
        .enb(1'b1),      // input wire enb
        .web(icache_we),      // input wire [3 : 0] web
        .addrb(icache_addr[18:2]),  // input wire [16 : 0] addrb
        .dinb(icache_din),    // input wire [31 : 0] dinb
        .doutb(icache_dout)  // output wire [31 : 0] doutb
    );

endmodule
