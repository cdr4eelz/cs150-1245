////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2013 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: P.68d
//  \   \         Application: netgen
//  /   /         Filename: mig_rdf.v
// /___/   /\     Timestamp: Mon Jun 19 01:15:40 2017
// \   \  /  \ 
//  \___\/\___\
//             
// Command	: -w -sim -ofmt verilog /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_rdf/tmp/_cg/mig_rdf.ngc /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_rdf/tmp/_cg/mig_rdf.v 
// Device	: 5vlx110tff1136-1
// Input file	: /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_rdf/tmp/_cg/mig_rdf.ngc
// Output file	: /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_rdf/tmp/_cg/mig_rdf.v
// # of Modules	: 2
// Design Name	: mig_rdf
// Xilinx        : /opt/Xilinx/14.6/ISE_DS/ISE/
//             
// Purpose:    
//     This verilog netlist is a verification model and uses simulation 
//     primitives which may not represent the true implementation of the 
//     device, however the netlist is functionally correct and should not 
//     be modified. This file cannot be synthesized and should only be used 
//     with supported simulation tools.
//             
// Reference:  
//     Command Line Tools User Guide, Chapter 23 and Synthesis and Simulation Design Guide, Chapter 6
//             
////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ps

module reset_builtin_RDF (
  CLK, RST, RD_CLK, INT_CLK, WR_CLK, RD_RST_I, WR_RST_I, INT_RST_I
)/* synthesis syn_black_box syn_noprune=1 */;
  input CLK;
  input RST;
  input RD_CLK;
  input INT_CLK;
  input WR_CLK;
  output [1 : 0] RD_RST_I;
  output [1 : 0] WR_RST_I;
  output [1 : 0] INT_RST_I;
  
  // synthesis translate_off
  
  wire rd_rst_reg_22;
  wire wr_rst_reg_28;
  wire [0 : 0] NlwRenamedSig_OI_INT_RST_I;
  wire [0 : 0] NlwRenamedSignal_RD_RST_I;
  wire [5 : 0] power_on_rd_rst;
  wire [5 : 0] power_on_wr_rst;
  wire [4 : 0] rd_rst_fb;
  wire [4 : 0] wr_rst_fb;
  assign
    RD_RST_I[1] = NlwRenamedSignal_RD_RST_I[0],
    RD_RST_I[0] = NlwRenamedSignal_RD_RST_I[0],
    INT_RST_I[1] = NlwRenamedSig_OI_INT_RST_I[0],
    INT_RST_I[0] = NlwRenamedSig_OI_INT_RST_I[0];
  GND   XST_GND (
    .G(NlwRenamedSig_OI_INT_RST_I[0])
  );
  FDPE #(
    .INIT ( 1'b0 ))
  rd_rst_reg (
    .C(RD_CLK),
    .CE(rd_rst_fb[0]),
    .D(NlwRenamedSig_OI_INT_RST_I[0]),
    .PRE(RST),
    .Q(rd_rst_reg_22)
  );
  FD #(
    .INIT ( 1'b0 ))
  wr_rst_fb_0 (
    .C(WR_CLK),
    .D(wr_rst_fb[1]),
    .Q(wr_rst_fb[0])
  );
  FD #(
    .INIT ( 1'b0 ))
  wr_rst_fb_1 (
    .C(WR_CLK),
    .D(wr_rst_fb[2]),
    .Q(wr_rst_fb[1])
  );
  FD #(
    .INIT ( 1'b0 ))
  wr_rst_fb_2 (
    .C(WR_CLK),
    .D(wr_rst_fb[3]),
    .Q(wr_rst_fb[2])
  );
  FD #(
    .INIT ( 1'b0 ))
  wr_rst_fb_3 (
    .C(WR_CLK),
    .D(wr_rst_fb[4]),
    .Q(wr_rst_fb[3])
  );
  FD #(
    .INIT ( 1'b0 ))
  wr_rst_fb_4 (
    .C(WR_CLK),
    .D(wr_rst_reg_28),
    .Q(wr_rst_fb[4])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_0 (
    .C(RD_CLK),
    .D(power_on_rd_rst[1]),
    .Q(power_on_rd_rst[0])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_1 (
    .C(RD_CLK),
    .D(power_on_rd_rst[2]),
    .Q(power_on_rd_rst[1])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_2 (
    .C(RD_CLK),
    .D(power_on_rd_rst[3]),
    .Q(power_on_rd_rst[2])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_3 (
    .C(RD_CLK),
    .D(power_on_rd_rst[4]),
    .Q(power_on_rd_rst[3])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_4 (
    .C(RD_CLK),
    .D(power_on_rd_rst[5]),
    .Q(power_on_rd_rst[4])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_rd_rst_5 (
    .C(RD_CLK),
    .D(NlwRenamedSig_OI_INT_RST_I[0]),
    .Q(power_on_rd_rst[5])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_0 (
    .C(WR_CLK),
    .D(power_on_wr_rst[1]),
    .Q(power_on_wr_rst[0])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_1 (
    .C(WR_CLK),
    .D(power_on_wr_rst[2]),
    .Q(power_on_wr_rst[1])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_2 (
    .C(WR_CLK),
    .D(power_on_wr_rst[3]),
    .Q(power_on_wr_rst[2])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_3 (
    .C(WR_CLK),
    .D(power_on_wr_rst[4]),
    .Q(power_on_wr_rst[3])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_4 (
    .C(WR_CLK),
    .D(power_on_wr_rst[5]),
    .Q(power_on_wr_rst[4])
  );
  FD #(
    .INIT ( 1'b1 ))
  power_on_wr_rst_5 (
    .C(WR_CLK),
    .D(NlwRenamedSig_OI_INT_RST_I[0]),
    .Q(power_on_wr_rst[5])
  );
  FDPE #(
    .INIT ( 1'b0 ))
  wr_rst_reg (
    .C(WR_CLK),
    .CE(wr_rst_fb[0]),
    .D(NlwRenamedSig_OI_INT_RST_I[0]),
    .PRE(RST),
    .Q(wr_rst_reg_28)
  );
  FD #(
    .INIT ( 1'b0 ))
  rd_rst_fb_0 (
    .C(RD_CLK),
    .D(rd_rst_fb[1]),
    .Q(rd_rst_fb[0])
  );
  FD #(
    .INIT ( 1'b0 ))
  rd_rst_fb_1 (
    .C(RD_CLK),
    .D(rd_rst_fb[2]),
    .Q(rd_rst_fb[1])
  );
  FD #(
    .INIT ( 1'b0 ))
  rd_rst_fb_2 (
    .C(RD_CLK),
    .D(rd_rst_fb[3]),
    .Q(rd_rst_fb[2])
  );
  FD #(
    .INIT ( 1'b0 ))
  rd_rst_fb_3 (
    .C(RD_CLK),
    .D(rd_rst_fb[4]),
    .Q(rd_rst_fb[3])
  );
  FD #(
    .INIT ( 1'b0 ))
  rd_rst_fb_4 (
    .C(RD_CLK),
    .D(rd_rst_reg_22),
    .Q(rd_rst_fb[4])
  );
  LUT2 #(
    .INIT ( 4'hE ))
  \RD_RST_I<1>1  (
    .I0(rd_rst_reg_22),
    .I1(power_on_rd_rst[0]),
    .O(NlwRenamedSignal_RD_RST_I[0])
  );

// synthesis translate_on

endmodule

module mig_rdf (
  rd_en, rst, empty, wr_en, rd_clk, valid, full, wr_clk, dout, din
)/* synthesis syn_black_box syn_noprune=1 */;
  input rd_en;
  input rst;
  output empty;
  input wr_en;
  input rd_clk;
  output valid;
  output full;
  input wr_clk;
  output [127 : 0] dout;
  input [127 : 0] din;
  
  // synthesis translate_off
  
  wire N0;
  wire N1;
  wire \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_32 ;
  wire \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ;
  wire \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_RD_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<31>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<30>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<29>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<28>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<27>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<26>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<25>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<24>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<23>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<22>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<21>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<20>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED ;
  wire [0 : 0] \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i ;
  wire [4 : 1] \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp ;
  wire [4 : 1] \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful ;
  assign
    valid = \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_32 ;
  GND   XST_GND (
    .G(N0)
  );
  VCC   XST_VCC (
    .P(N1)
  );
  reset_builtin_RDF   \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt  (
    .CLK(N0),
    .RST(rst),
    .RD_CLK(rd_clk),
    .INT_CLK(N0),
    .WR_CLK(wr_clk),
    .RD_RST_I({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_RD_RST_I<1>_UNCONNECTED , 
\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]}),
    .WR_RST_I({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<0>_UNCONNECTED }),
    .INT_RST_I({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<0>_UNCONNECTED })
  );
  FIFO36_EXP #(
    .ALMOST_FULL_OFFSET ( 13'h0004 ),
    .SIM_MODE ( "SAFE" ),
    .DATA_WIDTH ( 36 ),
    .DO_REG ( 1 ),
    .EN_SYN ( "FALSE" ),
    .FIRST_WORD_FALL_THROUGH ( "FALSE" ),
    .ALMOST_EMPTY_OFFSET ( 13'h0005 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36  (
    .RDEN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ),
    .WREN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i ),
    .RST(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .RDCLKU(rd_clk),
    .RDCLKL(rd_clk),
    .WRCLKU(wr_clk),
    .WRCLKL(wr_clk),
    .RDRCLKU(rd_clk),
    .RDRCLKL(rd_clk),
    .ALMOSTEMPTY
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ),
    .ALMOSTFULL
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ),
    .EMPTY(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [1]),
    .FULL(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [1]),
    .RDERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ),
    .WRERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ),
    .DI({din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], din[23], din[22], din[21], din[20], din[19], din[18], din[17], 
din[16], din[15], din[14], din[13], din[12], din[11], din[10], din[9], din[8], din[7], din[6], din[5], din[4], din[3], din[2], din[1], din[0]}),
    .DIP({din[35], din[34], din[33], din[32]}),
    .DO({dout[31], dout[30], dout[29], dout[28], dout[27], dout[26], dout[25], dout[24], dout[23], dout[22], dout[21], dout[20], dout[19], dout[18], 
dout[17], dout[16], dout[15], dout[14], dout[13], dout[12], dout[11], dout[10], dout[9], dout[8], dout[7], dout[6], dout[5], dout[4], dout[3], dout[2]
, dout[1], dout[0]}),
    .DOP({dout[35], dout[34], dout[33], dout[32]}),
    .RDCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED }),
    .WRCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED })
  );
  FIFO36_EXP #(
    .ALMOST_FULL_OFFSET ( 13'h0004 ),
    .SIM_MODE ( "SAFE" ),
    .DATA_WIDTH ( 36 ),
    .DO_REG ( 1 ),
    .EN_SYN ( "FALSE" ),
    .FIRST_WORD_FALL_THROUGH ( "FALSE" ),
    .ALMOST_EMPTY_OFFSET ( 13'h0005 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36  (
    .RDEN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ),
    .WREN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i ),
    .RST(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .RDCLKU(rd_clk),
    .RDCLKL(rd_clk),
    .WRCLKU(wr_clk),
    .WRCLKL(wr_clk),
    .RDRCLKU(rd_clk),
    .RDRCLKL(rd_clk),
    .ALMOSTEMPTY
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ),
    .ALMOSTFULL
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ),
    .EMPTY(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [2]),
    .FULL(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [2]),
    .RDERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ),
    .WRERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ),
    .DI({din[67], din[66], din[65], din[64], din[63], din[62], din[61], din[60], din[59], din[58], din[57], din[56], din[55], din[54], din[53], 
din[52], din[51], din[50], din[49], din[48], din[47], din[46], din[45], din[44], din[43], din[42], din[41], din[40], din[39], din[38], din[37], 
din[36]}),
    .DIP({din[71], din[70], din[69], din[68]}),
    .DO({dout[67], dout[66], dout[65], dout[64], dout[63], dout[62], dout[61], dout[60], dout[59], dout[58], dout[57], dout[56], dout[55], dout[54], 
dout[53], dout[52], dout[51], dout[50], dout[49], dout[48], dout[47], dout[46], dout[45], dout[44], dout[43], dout[42], dout[41], dout[40], dout[39], 
dout[38], dout[37], dout[36]}),
    .DOP({dout[71], dout[70], dout[69], dout[68]}),
    .RDCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED }),
    .WRCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[2].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED })
  );
  FIFO36_EXP #(
    .ALMOST_FULL_OFFSET ( 13'h0004 ),
    .SIM_MODE ( "SAFE" ),
    .DATA_WIDTH ( 36 ),
    .DO_REG ( 1 ),
    .EN_SYN ( "FALSE" ),
    .FIRST_WORD_FALL_THROUGH ( "FALSE" ),
    .ALMOST_EMPTY_OFFSET ( 13'h0005 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36  (
    .RDEN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ),
    .WREN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i ),
    .RST(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .RDCLKU(rd_clk),
    .RDCLKL(rd_clk),
    .WRCLKU(wr_clk),
    .WRCLKL(wr_clk),
    .RDRCLKU(rd_clk),
    .RDRCLKL(rd_clk),
    .ALMOSTEMPTY
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ),
    .ALMOSTFULL
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ),
    .EMPTY(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [3]),
    .FULL(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [3]),
    .RDERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ),
    .WRERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ),
    .DI({din[103], din[102], din[101], din[100], din[99], din[98], din[97], din[96], din[95], din[94], din[93], din[92], din[91], din[90], din[89], 
din[88], din[87], din[86], din[85], din[84], din[83], din[82], din[81], din[80], din[79], din[78], din[77], din[76], din[75], din[74], din[73], 
din[72]}),
    .DIP({din[107], din[106], din[105], din[104]}),
    .DO({dout[103], dout[102], dout[101], dout[100], dout[99], dout[98], dout[97], dout[96], dout[95], dout[94], dout[93], dout[92], dout[91], 
dout[90], dout[89], dout[88], dout[87], dout[86], dout[85], dout[84], dout[83], dout[82], dout[81], dout[80], dout[79], dout[78], dout[77], dout[76], 
dout[75], dout[74], dout[73], dout[72]}),
    .DOP({dout[107], dout[106], dout[105], dout[104]}),
    .RDCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED }),
    .WRCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[3].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED })
  );
  FIFO36_EXP #(
    .ALMOST_FULL_OFFSET ( 13'h0004 ),
    .SIM_MODE ( "SAFE" ),
    .DATA_WIDTH ( 36 ),
    .DO_REG ( 1 ),
    .EN_SYN ( "FALSE" ),
    .FIRST_WORD_FALL_THROUGH ( "FALSE" ),
    .ALMOST_EMPTY_OFFSET ( 13'h0005 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36  (
    .RDEN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ),
    .WREN(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i ),
    .RST(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .RDCLKU(rd_clk),
    .RDCLKL(rd_clk),
    .WRCLKU(wr_clk),
    .WRCLKL(wr_clk),
    .RDRCLKU(rd_clk),
    .RDRCLKL(rd_clk),
    .ALMOSTEMPTY
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ),
    .ALMOSTFULL
(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ),
    .EMPTY(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [4]),
    .FULL(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [4]),
    .RDERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ),
    .WRERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ),
    .DI({N0, N0, N0, N0, N0, N0, N0, N0, N0, N0, N0, N0, din[127], din[126], din[125], din[124], din[123], din[122], din[121], din[120], din[119], 
din[118], din[117], din[116], din[115], din[114], din[113], din[112], din[111], din[110], din[109], din[108]}),
    .DIP({N0, N0, N0, N0}),
    .DO({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<31>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<30>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<29>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<28>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<27>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<26>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<25>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<24>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<23>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<22>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<21>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DO<20>_UNCONNECTED , dout[127], 
dout[126], dout[125], dout[124], dout[123], dout[122], dout[121], dout[120], dout[119], dout[118], dout[117], dout[116], dout[115], dout[114], 
dout[113], dout[112], dout[111], dout[110], dout[109], dout[108]}),
    .DOP({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<0>_UNCONNECTED }),
    .RDCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDCOUNT<0>_UNCONNECTED }),
    .WRCOUNT({
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<12>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<11>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<10>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<9>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<8>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<7>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<6>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<5>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<4>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<2>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<1>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[4].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRCOUNT<0>_UNCONNECTED })
  );
  FDC #(
    .INIT ( 1'b0 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID  (
    .C(rd_clk),
    .CLR(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .D(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp ),
    .Q(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_32 )
  );
  LUT4 #(
    .INIT ( 16'hFFFE ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/empty_i1  (
    .I0(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [2]),
    .I1(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [1]),
    .I2(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [4]),
    .I3(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [3]),
    .O(empty)
  );
  LUT4 #(
    .INIT ( 16'hFFFE ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/full_i1  (
    .I0(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [2]),
    .I1(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [1]),
    .I2(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [4]),
    .I3(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [3]),
    .O(full)
  );
  LUT5 #(
    .INIT ( 32'h00000002 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i1  (
    .I0(wr_en),
    .I1(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [3]),
    .I2(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [4]),
    .I3(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [1]),
    .I4(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/ful [2]),
    .O(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/wr_ack_i )
  );
  LUT5 #(
    .INIT ( 32'h00000002 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp1  (
    .I0(rd_en),
    .I1(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [3]),
    .I2(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [4]),
    .I3(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [1]),
    .I4(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/emp [2]),
    .O(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/rd_tmp )
  );

// synthesis translate_on

endmodule

// synthesis translate_off

`ifndef GLBL
`define GLBL

`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;

    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (weak1, weak0) GSR = GSR_int;
    assign (weak1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule

`endif

// synthesis translate_on
