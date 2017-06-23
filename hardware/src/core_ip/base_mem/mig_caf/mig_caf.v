////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2013 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: P.68d
//  \   \         Application: netgen
//  /   /         Filename: mig_caf.v
// /___/   /\     Timestamp: Thu Jun 22 05:30:27 2017
// \   \  /  \ 
//  \___\/\___\
//             
// Command	: -w -sim -ofmt verilog /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_caf/tmp/_cg/mig_caf.ngc /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_caf/tmp/_cg/mig_caf.v 
// Device	: 5vlx110tff1136-1
// Input file	: /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_caf/tmp/_cg/mig_caf.ngc
// Output file	: /home/cc/cs199/fa12/class/cs199-fu/team45/hardware/src/core_ip/base_mem/mig_caf/tmp/_cg/mig_caf.v
// # of Modules	: 2
// Design Name	: mig_caf
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

module reset_builtin_CAF (
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
  
  wire rd_rst_reg_23;
  wire wr_rst_reg_29;
  wire [0 : 0] NlwRenamedSig_OI_INT_RST_I;
  wire [0 : 0] NlwRenamedSignal_RD_RST_I;
  wire [0 : 0] NlwRenamedSignal_WR_RST_I;
  wire [5 : 0] power_on_rd_rst;
  wire [5 : 0] power_on_wr_rst;
  wire [4 : 0] rd_rst_fb;
  wire [4 : 0] wr_rst_fb;
  assign
    RD_RST_I[1] = NlwRenamedSignal_RD_RST_I[0],
    RD_RST_I[0] = NlwRenamedSignal_RD_RST_I[0],
    WR_RST_I[1] = NlwRenamedSignal_WR_RST_I[0],
    WR_RST_I[0] = NlwRenamedSignal_WR_RST_I[0],
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
    .Q(rd_rst_reg_23)
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
    .D(wr_rst_reg_29),
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
    .Q(wr_rst_reg_29)
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
    .D(rd_rst_reg_23),
    .Q(rd_rst_fb[4])
  );
  LUT2 #(
    .INIT ( 4'hE ))
  \WR_RST_I<1>1  (
    .I0(wr_rst_reg_29),
    .I1(power_on_wr_rst[0]),
    .O(NlwRenamedSignal_WR_RST_I[0])
  );
  LUT2 #(
    .INIT ( 4'hE ))
  \RD_RST_I<1>1  (
    .I0(rd_rst_reg_23),
    .I1(power_on_rd_rst[0]),
    .O(NlwRenamedSignal_RD_RST_I[0])
  );

// synthesis translate_on

endmodule

module mig_caf (
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
  output [33 : 0] dout;
  input [33 : 0] din;
  
  // synthesis translate_off
  
  wire N0;
  wire N1;
  wire \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_33 ;
  wire \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/valid_i ;
  wire NlwRenamedSig_OI_empty;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_RD_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<1>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_INT_RST_I<0>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTEMPTY_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_ALMOSTFULL_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<3>_UNCONNECTED ;
  wire \NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<2>_UNCONNECTED ;
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
  wire [0 : 0] \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i ;
  wire [0 : 0] \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/wr_rst_i ;
  assign
    empty = NlwRenamedSig_OI_empty,
    valid = \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_33 ;
  GND   XST_GND (
    .G(N0)
  );
  VCC   XST_VCC (
    .P(N1)
  );
  reset_builtin_CAF   \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt  (
    .CLK(N0),
    .RST(rst),
    .RD_CLK(rd_clk),
    .INT_CLK(N0),
    .WR_CLK(wr_clk),
    .RD_RST_I({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_RD_RST_I<1>_UNCONNECTED , 
\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]}),
    .WR_RST_I({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt_WR_RST_I<1>_UNCONNECTED , 
\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/wr_rst_i [0]}),
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
    .RDEN(rd_en),
    .WREN(wr_en),
    .RST(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/wr_rst_i [0]),
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
    .EMPTY(NlwRenamedSig_OI_empty),
    .FULL(full),
    .RDERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_RDERR_UNCONNECTED ),
    .WRERR(\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_WRERR_UNCONNECTED ),
    .DI({din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], din[23], din[22], din[21], din[20], din[19], din[18], din[17], 
din[16], din[15], din[14], din[13], din[12], din[11], din[10], din[9], din[8], din[7], din[6], din[5], din[4], din[3], din[2], din[1], din[0]}),
    .DIP({N0, N0, din[33], din[32]}),
    .DO({dout[31], dout[30], dout[29], dout[28], dout[27], dout[26], dout[25], dout[24], dout[23], dout[22], dout[21], dout[20], dout[19], dout[18], 
dout[17], dout[16], dout[15], dout[14], dout[13], dout[12], dout[11], dout[10], dout[9], dout[8], dout[7], dout[6], dout[5], dout[4], dout[3], dout[2]
, dout[1], dout[0]}),
    .DOP({\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<3>_UNCONNECTED , 
\NLW_U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/gextw[1].inst_extd/gonep.inst_prim/gfn72.sngfifo36_DOP<2>_UNCONNECTED , dout[33], 
dout[32]}),
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
  FDC #(
    .INIT ( 1'b0 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID  (
    .C(rd_clk),
    .CLR(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rd_rst_i [0]),
    .D(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/valid_i ),
    .Q(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/VALID_33 )
  );
  LUT2 #(
    .INIT ( 4'h2 ))
  \U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/valid_i1  (
    .I0(rd_en),
    .I1(NlwRenamedSig_OI_empty),
    .O(\U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/v5_fifo.fblk/valid_i )
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
