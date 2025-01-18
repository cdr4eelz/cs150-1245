--*****************************************************************************
-- DISCLAIMER OF LIABILITY
--
-- This file contains proprietary and confidential information of
-- Xilinx, Inc. ("Xilinx"), that is distributed under a license
-- from Xilinx, and may be used, copied and/or disclosed only
-- pursuant to the terms of a valid license agreement with Xilinx.
--
-- XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION
-- ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
-- EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT
-- LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,
-- MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx
-- does not warrant that functions included in the Materials will
-- meet the requirements of Licensee, or that the operation of the
-- Materials will be uninterrupted or error-free, or that defects
-- in the Materials will be corrected. Furthermore, Xilinx does
-- not warrant or make any representations regarding use, or the
-- results of the use, of the Materials in terms of correctness,
-- accuracy, reliability or otherwise.
--
-- Xilinx products are not designed or intended to be fail-safe,
-- or for use in any application requiring fail-safe performance,
-- such as life-support or safety devices or systems, Class III
-- medical devices, nuclear facilities, applications related to
-- the deployment of airbags, or any other applications that could
-- lead to death, personal injury or severe property or
-- environmental damage (individually and collectively, "critical
-- applications"). Customer assumes the sole risk and liability
-- of any use of Xilinx products in critical applications,
-- subject only to applicable laws and regulations governing
-- limitations on product liability.
--
-- Copyright 2006, 2007, 2008 Xilinx, Inc.
-- All rights reserved.
--
-- This disclaimer and copyright notice must be retained as part
-- of this file at all times.
--*****************************************************************************
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor: Xilinx
-- \   \   \/     Version: 3.6.1
--  \   \         Application: MIG
--  /   /         Filename: mig_3_6_1.vhd
-- /___/   /\     Date Last Modified: $Date: 2010/11/26 18:26:03 $
-- \   \  /  \    Date Created: Wed Jan 10 2007
--  \___\/\___\
--
--Device: Virtex-5
--Design Name: DDR2
--Purpose:
--   Top-level  module. Simple model for what the user might use
--   typically, the user will only instantiate MEM_INTERFACE_TOP in their
--   code, and generate all the other infrastructure logic separately. 
--   This module serves both as an example, and allows the user
--   to synthesize a self-contained design, which they can use to test their
--   hardware.
--   In addition to the memory controller, the module instantiates:
--     1. Reset logic based on user clocks
--     2. IDELAY control block
--     3. Synthesizable testbench - used to model user's backend logic
--Reference:
--Revision History:
--   Rev 1.1 - Parameter USE_DM_PORT added. PK. 6/25/08
--   Rev 1.2 - Parameter HIGH_PERFORMANCE_MODE added. PK. 7/10/08
--   Rev 1.3 - Parameter IODELAY_GRP added. PK. 11/27/08
--*****************************************************************************

library ieee;

use ieee.std_logic_1164.all;

use work.ddr2_chipscope.all;

entity mig_3_6_1 is
  generic(
   MY_DEBUG                 : integer := 0;
   BANK_WIDTH               : integer := 2; 
                              -- # of memory bank addr bits.
   CKE_WIDTH                : integer := 1; 
                              -- # of memory clock enable outputs.
   CLK_WIDTH                : integer := 2; 
                              -- # of clock outputs.
   COL_WIDTH                : integer := 10; 
                              -- # of memory column bits.
   CS_NUM                   : integer := 1; 
                              -- # of separate memory chip selects.
   CS_WIDTH                 : integer := 1; 
                              -- # of total memory chip selects.
   CS_BITS                  : integer := 0; 
                              -- set to log2(CS_NUM) (rounded up).
   DM_WIDTH                 : integer := 8; 
                              -- # of data mask bits.
   DQ_WIDTH                 : integer := 64; 
                              -- # of data width.
   DQ_PER_DQS               : integer := 8; 
                              -- # of DQ data bits per strobe.
   DQS_WIDTH                : integer := 8; 
                              -- # of DQS strobes.
   DQ_BITS                  : integer := 6; 
                              -- set to log2(DQS_WIDTH*DQ_PER_DQS).
   DQS_BITS                 : integer := 3; 
                              -- set to log2(DQS_WIDTH).
   ODT_WIDTH                : integer := 1; 
                              -- # of memory on-die term enables.
   ROW_WIDTH                : integer := 13; 
                              -- # of memory row and # of addr bits.
   ADDITIVE_LAT             : integer := 0; 
                              -- additive write latency.
   BURST_LEN                : integer := 4; 
                              -- burst length (in double words).
   BURST_TYPE               : integer := 0; 
                              -- burst type (=0 seq; =1 interleaved).
   CAS_LAT                  : integer := 3; 
                              -- CAS latency.
   ECC_ENABLE               : integer := 0; 
                              -- enable ECC (=1 enable).
   APPDATA_WIDTH            : integer := 128; 
                              -- # of usr read/write data bus bits.
   MULTI_BANK_EN            : integer := 1; 
                              -- Keeps multiple banks open. (= 1 enable).
   TWO_T_TIME_EN            : integer := 1; 
                              -- 2t timing for unbuffered dimms.
   ODT_TYPE                 : integer := 1; 
                              -- ODT (=0(none),=1(75),=2(150),=3(50)).
   REDUCE_DRV               : integer := 0; 
                              -- reduced strength mem I/O (=1 yes).
   REG_ENABLE               : integer := 0; 
                              -- registered addr/ctrl (=1 yes).
   TREFI_NS                 : integer := 7800; 
                              -- auto refresh interval (ns).
   TRAS                     : integer := 40000; 
                              -- active->precharge delay.
   TRCD                     : integer := 15000; 
                              -- active->read/write delay.
   TRFC                     : integer := 105000; 
                              -- refresh->refresh, refresh->active delay.
   TRP                      : integer := 15000; 
                              -- precharge->command delay.
   TRTP                     : integer := 7500; 
                              -- read->precharge delay.
   TWR                      : integer := 15000; 
                              -- used to determine write->precharge.
   TWTR                     : integer := 7500; 
                              -- write->read delay.
   HIGH_PERFORMANCE_MODE    : boolean := TRUE; 
                              -- # = TRUE, the IODELAY performance mode is set
                              -- to high.
                              -- # = FALSE, the IODELAY performance mode is set
                              -- to low.
   SIM_ONLY                 : integer := 0; 
                              -- = 1 to skip SDRAM power up delay.
   DEBUG_EN                 : integer := 0;
                              -- Enable debug signals/controls.
                              -- When this parameter is changed from 0 to 1,
                              -- make sure to uncomment the coregen commands
                              -- in ise_flow.bat or create_ise.bat files in
                              -- par folder.
   CLK_PERIOD               : integer := 5000; 
                              -- Core/Memory clock period (in ps).
   DLL_FREQ_MODE            : string := "HIGH"; 
                              -- DCM Frequency range.
   CLK_TYPE                 : string := "DIFFERENTIAL"; 
                              -- # = "DIFFERENTIAL " ->; Differential input clocks ,
                              -- # = "SINGLE_ENDED" -> Single ended input clocks.
   NOCLK200                 : boolean := FALSE; 
                              -- clk200 enable and disable
   RST_ACT_LOW              : integer := 1  
                              -- =1 for active low reset, =0 for active high.
   );
  port(
   ddr2_dq               : inout  std_logic_vector((DQ_WIDTH-1) downto 0);
   ddr2_a                : out   std_logic_vector((ROW_WIDTH-1) downto 0);
   ddr2_ba               : out   std_logic_vector((BANK_WIDTH-1) downto 0);
   ddr2_ras_n            : out   std_logic;
   ddr2_cas_n            : out   std_logic;
   ddr2_we_n             : out   std_logic;
   ddr2_cs_n             : out   std_logic_vector((CS_WIDTH-1) downto 0);
   ddr2_odt              : out   std_logic_vector((ODT_WIDTH-1) downto 0);
   ddr2_cke              : out   std_logic_vector((CKE_WIDTH-1) downto 0);
   ddr2_dm               : out   std_logic_vector((DM_WIDTH-1) downto 0);
   sys_clk_p             : in    std_logic;
   sys_clk_n             : in    std_logic;
   clk200_p              : in    std_logic;
   clk200_n              : in    std_logic;
   sys_rst_n             : in    std_logic;
   phy_init_done         : out   std_logic;
   error                 : out   std_logic;
   ddr2_dqs              : inout  std_logic_vector((DQS_WIDTH-1) downto 0);
   ddr2_dqs_n            : inout  std_logic_vector((DQS_WIDTH-1) downto 0);
   ddr2_ck               : out   std_logic_vector((CLK_WIDTH-1) downto 0);
   ddr2_ck_n             : out   std_logic_vector((CLK_WIDTH-1) downto 0)
   );

end entity mig_3_6_1;

architecture arc_mem_interface_top of mig_3_6_1 is

  --***************************************************************************
  -- IODELAY Group Name: Replication and placement of IDELAYCTRLs will be
  -- handled automatically by software tools if IDELAYCTRLs have same refclk,
  -- reset and rdy nets. Designs with a unique RESET will commonly create a
  -- unique RDY. Constraint IODELAY_GROUP is associated to a set of IODELAYs
  -- with an IDELAYCTRL. The parameter IODELAY_GRP value can be any string.
  --***************************************************************************
  constant IODELAY_GRP : string := "IODELAY_MIG";



  component ddr2_idelay_ctrl
    generic (
      IODELAY_GRP       : string
      );
    port (
      rst200               : in    std_logic;
      clk200               : in    std_logic;
      idelay_ctrl_rdy      : out   std_logic
      );
  end component;

component ddr2_infrastructure
    generic (
      CLK_PERIOD            : integer;
      DLL_FREQ_MODE         : string;
      CLK_TYPE              : string;
      NOCLK200              : boolean;
      RST_ACT_LOW           : integer

      );
    port (
      sys_clk_p            : in    std_logic;
      sys_clk_n            : in    std_logic;
      sys_clk              : in    std_logic;
      clk200_p             : in    std_logic;
      clk200_n             : in    std_logic;
      idly_clk_200         : in    std_logic;
      sys_rst_n            : in    std_logic;
      rst0                 : out   std_logic;
      rst90                : out   std_logic;
      rstdiv0              : out   std_logic;
      rst200               : out   std_logic;
      clk0                 : out   std_logic;
      clk90                : out   std_logic;
      clkdiv0              : out   std_logic;
      clk200               : out   std_logic;
      idelay_ctrl_rdy      : in    std_logic

      );
  end component;


component ddr2_top
    generic (
      BANK_WIDTH            : integer;
      CKE_WIDTH             : integer;
      CLK_WIDTH             : integer;
      COL_WIDTH             : integer;
      CS_NUM                : integer;
      CS_WIDTH              : integer;
      CS_BITS               : integer;
      DM_WIDTH              : integer;
      DQ_WIDTH              : integer;
      DQ_PER_DQS            : integer;
      DQS_WIDTH             : integer;
      DQ_BITS               : integer;
      DQS_BITS              : integer;
      ODT_WIDTH             : integer;
      ROW_WIDTH             : integer;
      ADDITIVE_LAT          : integer;
      BURST_LEN             : integer;
      BURST_TYPE            : integer;
      CAS_LAT               : integer;
      ECC_ENABLE            : integer;
      APPDATA_WIDTH         : integer;
      MULTI_BANK_EN         : integer;
      TWO_T_TIME_EN         : integer;
      ODT_TYPE              : integer;
      REDUCE_DRV            : integer;
      REG_ENABLE            : integer;
      TREFI_NS              : integer;
      TRAS                  : integer;
      TRCD                  : integer;
      TRFC                  : integer;
      TRP                   : integer;
      TRTP                  : integer;
      TWR                   : integer;
      TWTR                  : integer;
      HIGH_PERFORMANCE_MODE   : boolean;
      IODELAY_GRP           : string;
      SIM_ONLY              : integer;
      DEBUG_EN              : integer;
      FPGA_SPEED_GRADE      : integer;
      USE_DM_PORT           : integer;
      CLK_PERIOD            : integer
      );
    port (
      ddr2_dq              : inout  std_logic_vector((DQ_WIDTH-1) downto 0);
      ddr2_a               : out   std_logic_vector((ROW_WIDTH-1) downto 0);
      ddr2_ba              : out   std_logic_vector((BANK_WIDTH-1) downto 0);
      ddr2_ras_n           : out   std_logic;
      ddr2_cas_n           : out   std_logic;
      ddr2_we_n            : out   std_logic;
      ddr2_cs_n            : out   std_logic_vector((CS_WIDTH-1) downto 0);
      ddr2_odt             : out   std_logic_vector((ODT_WIDTH-1) downto 0);
      ddr2_cke             : out   std_logic_vector((CKE_WIDTH-1) downto 0);
      ddr2_dm              : out   std_logic_vector((DM_WIDTH-1) downto 0);
      phy_init_done        : out   std_logic;
      rst0                 : in    std_logic;
      rst90                : in    std_logic;
      rstdiv0              : in    std_logic;
      clk0                 : in    std_logic;
      clk90                : in    std_logic;
      clkdiv0              : in    std_logic;
      app_wdf_afull        : out   std_logic;
      app_af_afull         : out   std_logic;
      rd_data_valid        : out   std_logic;
      app_wdf_wren         : in    std_logic;
      app_af_wren          : in    std_logic;
      app_af_addr          : in    std_logic_vector(30 downto 0);
      app_af_cmd           : in    std_logic_vector(2 downto 0);
      rd_data_fifo_out     : out   std_logic_vector((APPDATA_WIDTH-1) downto 0);
      app_wdf_data         : in    std_logic_vector((APPDATA_WIDTH-1) downto 0);
      app_wdf_mask_data    : in    std_logic_vector((APPDATA_WIDTH/8-1) downto 0);
      ddr2_dqs             : inout  std_logic_vector((DQS_WIDTH-1) downto 0);
      ddr2_dqs_n           : inout  std_logic_vector((DQS_WIDTH-1) downto 0);
      ddr2_ck              : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      rd_ecc_error         : out   std_logic_vector(1 downto 0);
      ddr2_ck_n            : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      dbg_calib_done          : out  std_logic_vector(3 downto 0);
      dbg_calib_err           : out  std_logic_vector(3 downto 0);
      dbg_calib_dq_tap_cnt    : out  std_logic_vector(((6*DQ_WIDTH)-1) downto 0);
      dbg_calib_dqs_tap_cnt   : out  std_logic_vector(((6*DQS_WIDTH)-1) downto 0);
      dbg_calib_gate_tap_cnt   : out  std_logic_vector(((6*DQS_WIDTH)-1) downto 0);
      dbg_calib_rd_data_sel   : out  std_logic_vector((DQS_WIDTH-1) downto 0);
      dbg_calib_rden_dly      : out  std_logic_vector(((5*DQS_WIDTH)-1) downto 0);
      dbg_calib_gate_dly      : out  std_logic_vector(((5*DQS_WIDTH)-1) downto 0);
      dbg_idel_up_all         : in  std_logic;
      dbg_idel_down_all       : in  std_logic;
      dbg_idel_up_dq          : in  std_logic;
      dbg_idel_down_dq        : in  std_logic;
      dbg_idel_up_dqs         : in  std_logic;
      dbg_idel_down_dqs       : in  std_logic;
      dbg_idel_up_gate        : in  std_logic;
      dbg_idel_down_gate      : in  std_logic;
      dbg_sel_idel_dq         : in  std_logic_vector((DQ_BITS-1) downto 0);
      dbg_sel_all_idel_dq     : in  std_logic;
      dbg_sel_idel_dqs        : in  std_logic_vector(DQS_BITS downto 0);
      dbg_sel_all_idel_dqs    : in  std_logic;
      dbg_sel_idel_gate       : in  std_logic_vector(DQS_BITS downto 0);
      dbg_sel_all_idel_gate   : in  std_logic

      );
  end component;


component  ddr2_tb_top
    generic (
      BANK_WIDTH            : integer;
      COL_WIDTH             : integer;
      DM_WIDTH              : integer;
      DQ_WIDTH              : integer;
      ROW_WIDTH             : integer;
      BURST_LEN             : integer;
      ECC_ENABLE            : integer;
      APPDATA_WIDTH         : integer
      );
    port (
      phy_init_done        : in    std_logic;
      error                : out   std_logic;
      error_cmp            : out   std_logic;
      rst0                 : in    std_logic;
      clk0                 : in    std_logic;
      app_wdf_afull        : in    std_logic;
      app_af_afull         : in    std_logic;
      rd_data_valid        : in    std_logic;
      app_wdf_wren         : out   std_logic;
      app_af_wren          : out   std_logic;
      app_af_addr          : out   std_logic_vector(30 downto 0);
      app_af_cmd           : out   std_logic_vector(2 downto 0);
      rd_data_fifo_out     : in    std_logic_vector((APPDATA_WIDTH-1) downto 0);
      app_wdf_data         : out   std_logic_vector((APPDATA_WIDTH-1) downto 0);
      app_wdf_mask_data    : out   std_logic_vector((APPDATA_WIDTH/8-1) downto 0)
      );
  end component;


  signal  sys_clk                : std_logic;
  signal  idly_clk_200           : std_logic;
  signal  error_cmp              : std_logic;
  signal  rst0                   : std_logic;
  signal  rst90                  : std_logic;
  signal  rstdiv0                : std_logic;
  signal  rst200                 : std_logic;
  signal  clk0                   : std_logic;
  signal  clk90                  : std_logic;
  signal  clkdiv0                : std_logic;
  signal  clk200                 : std_logic;
  signal  idelay_ctrl_rdy        : std_logic;
  signal  app_wdf_afull          : std_logic;
  signal  app_af_afull           : std_logic;
  signal  rd_data_valid          : std_logic;
  signal  app_wdf_wren           : std_logic;
  signal  app_af_wren            : std_logic;
  signal  app_af_addr            : std_logic_vector(30 downto 0);
  signal  app_af_cmd             : std_logic_vector(2 downto 0);
  signal  rd_data_fifo_out       : std_logic_vector((APPDATA_WIDTH)-1 downto 0);
  signal  app_wdf_data           : std_logic_vector((APPDATA_WIDTH)-1 downto 0);
  signal  app_wdf_mask_data      : std_logic_vector((APPDATA_WIDTH/8)-1 downto 0);
  signal  i_phy_init_done      : std_logic;
  signal  i_error              : std_logic;


  --Debug signals


  signal  dbg_calib_done             : std_logic_vector(3 downto 0);
  signal  dbg_calib_err              : std_logic_vector(3 downto 0);
  signal  dbg_calib_dq_tap_cnt       : std_logic_vector(((6*DQ_WIDTH)-1) downto 0);
  signal  dbg_calib_dqs_tap_cnt      : std_logic_vector(((6*DQS_WIDTH)-1) downto 0);
  signal  dbg_calib_gate_tap_cnt     : std_logic_vector(((6*DQS_WIDTH)-1) downto 0);
  signal  dbg_calib_rd_data_sel      : std_logic_vector((DQS_WIDTH-1) downto 0);
  signal  dbg_calib_rden_dly         : std_logic_vector(((5*DQS_WIDTH)-1) downto 0);
  signal  dbg_calib_gate_dly         : std_logic_vector(((5*DQS_WIDTH)-1) downto 0);
  signal  dbg_idel_up_all            : std_logic;
  signal  dbg_idel_down_all          : std_logic;
  signal  dbg_idel_up_dq             : std_logic;
  signal  dbg_idel_down_dq           : std_logic;
  signal  dbg_idel_up_dqs            : std_logic;
  signal  dbg_idel_down_dqs          : std_logic;
  signal  dbg_idel_up_gate           : std_logic;
  signal  dbg_idel_down_gate         : std_logic;
  signal  dbg_sel_idel_dq            : std_logic_vector((DQ_BITS-1) downto 0);
  signal  dbg_sel_all_idel_dq        : std_logic;
  signal  dbg_sel_idel_dqs           : std_logic_vector(DQS_BITS downto 0);
  signal  dbg_sel_all_idel_dqs       : std_logic;
  signal  dbg_sel_idel_gate          : std_logic_vector(DQS_BITS downto 0);
  signal  dbg_sel_all_idel_gate      : std_logic;


 -- Debug signals (optional use)

  --***********************************
  -- PHY Debug Port demo
  --***********************************
  signal cs_control0            : std_logic_vector(35 downto 0);
  signal cs_control1            : std_logic_vector(35 downto 0);
  signal cs_control2            : std_logic_vector(35 downto 0);
  signal cs_control3            : std_logic_vector(35 downto 0);
  signal vio0_in                : std_logic_vector(191 downto 0);
  signal vio1_in                : std_logic_vector(95 downto 0);
  signal vio2_in                : std_logic_vector(99 downto 0);
  signal vio3_out               : std_logic_vector(31 downto 0);




  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of arc_mem_interface_top : architecture IS
    "mig_v3_61_ddr2_v5, Coregen 12.4";

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of arc_mem_interface_top : architecture IS "ddr2_v5,mig_v3_61,{component_name=mig_3_6_1, BANK_WIDTH=2, CKE_WIDTH=1, CLK_WIDTH=2, COL_WIDTH=10, CS_NUM=1, CS_WIDTH=1, DM_WIDTH=8, DQ_WIDTH=64, DQ_PER_DQS=8, DQS_WIDTH=8, ODT_WIDTH=1, ROW_WIDTH=13, ADDITIVE_LAT=0, BURST_LEN=4, BURST_TYPE=0, CAS_LAT=3, ECC_ENABLE=0, MULTI_BANK_EN=1, TWO_T_TIME_EN=1, ODT_TYPE=1, REDUCE_DRV=0, REG_ENABLE=0, TREFI_NS=7800, TRAS=40000, TRCD=15000, TRFC=105000, TRP=15000, TRTP=7500, TWR=15000, TWTR=7500, CLK_PERIOD=5000, RST_ACT_LOW=1, INTERFACE_TYPE=DDR2_SDRAM, LANGUAGE=VHDL, SYNTHESIS_TOOL=ISE, NO_OF_CONTROLLERS=1}";


-- Tutorial debug insertions --
  component micon_1
    port (
        CONTROL0: inout std_logic_vector(35 downto 0)
    );
  end component;
  component mila
    port (
        CONTROL: inout std_logic_vector(35 downto 0);
        CLK: in std_logic;
        DATA: in std_logic_vector(71 downto 0);
        TRIG0: in std_logic_vector(7 downto 0)
    );
  end component;
  attribute syn_black_box : boolean;
  attribute syn_noprune   : boolean;
  attribute syn_noprune   of micon_1         : component is TRUE;
  attribute syn_black_box of micon_1         : component is TRUE;
  attribute syn_noprune   of mila            : component is TRUE;
  attribute syn_black_box of mila            : component is TRUE;
  signal my_control         : std_logic_vector(35 downto 0);
  signal my_data            : std_logic_vector(71 downto 0);
  signal my_trig0           : std_logic_vector(7 downto 0);
-- Tutorial debug insertions --

begin


  --***************************************************************************
  phy_init_done   <= i_phy_init_done;
  error   <= i_error;
  sys_clk <= '0';
  idly_clk_200 <= '0';

  u_ddr2_idelay_ctrl : ddr2_idelay_ctrl
    generic map (
      IODELAY_GRP        => IODELAY_GRP
   )
    port map (
      rst200                => rst200,
      clk200                => clk200,
      idelay_ctrl_rdy       => idelay_ctrl_rdy
   );

u_ddr2_infrastructure :ddr2_infrastructure
    generic map (
      CLK_PERIOD            => CLK_PERIOD,
      DLL_FREQ_MODE         => DLL_FREQ_MODE,
      CLK_TYPE              => CLK_TYPE,
      NOCLK200              => NOCLK200,
      RST_ACT_LOW           => RST_ACT_LOW
   )
    port map (
      sys_clk_p             => sys_clk_p,
      sys_clk_n             => sys_clk_n,
      sys_clk               => sys_clk,
      clk200_p              => clk200_p,
      clk200_n              => clk200_n,
      idly_clk_200          => idly_clk_200,
      sys_rst_n             => sys_rst_n,
      rst0                  => rst0,
      rst90                 => rst90,
      rstdiv0               => rstdiv0,
      rst200                => rst200,
      clk0                  => clk0,
      clk90                 => clk90,
      clkdiv0               => clkdiv0,
      clk200                => clk200,
      idelay_ctrl_rdy       => idelay_ctrl_rdy
   );

  u_ddr2_top_0 : ddr2_top
    generic map (
      BANK_WIDTH            => BANK_WIDTH,
      CKE_WIDTH             => CKE_WIDTH,
      CLK_WIDTH             => CLK_WIDTH,
      COL_WIDTH             => COL_WIDTH,
      CS_NUM                => CS_NUM,
      CS_WIDTH              => CS_WIDTH,
      CS_BITS               => CS_BITS,
      DM_WIDTH              => DM_WIDTH,
      DQ_WIDTH              => DQ_WIDTH,
      DQ_PER_DQS            => DQ_PER_DQS,
      DQS_WIDTH             => DQS_WIDTH,
      DQ_BITS               => DQ_BITS,
      DQS_BITS              => DQS_BITS,
      ODT_WIDTH             => ODT_WIDTH,
      ROW_WIDTH             => ROW_WIDTH,
      ADDITIVE_LAT          => ADDITIVE_LAT,
      BURST_LEN             => BURST_LEN,
      BURST_TYPE            => BURST_TYPE,
      CAS_LAT               => CAS_LAT,
      ECC_ENABLE            => ECC_ENABLE,
      APPDATA_WIDTH         => APPDATA_WIDTH,
      MULTI_BANK_EN         => MULTI_BANK_EN,
      TWO_T_TIME_EN         => TWO_T_TIME_EN,
      ODT_TYPE              => ODT_TYPE,
      REDUCE_DRV            => REDUCE_DRV,
      REG_ENABLE            => REG_ENABLE,
      TREFI_NS              => TREFI_NS,
      TRAS                  => TRAS,
      TRCD                  => TRCD,
      TRFC                  => TRFC,
      TRP                   => TRP,
      TRTP                  => TRTP,
      TWR                   => TWR,
      TWTR                  => TWTR,
      HIGH_PERFORMANCE_MODE   => HIGH_PERFORMANCE_MODE,
      IODELAY_GRP           => IODELAY_GRP,
      SIM_ONLY              => SIM_ONLY,
      DEBUG_EN              => DEBUG_EN,
      FPGA_SPEED_GRADE      => 1,
      USE_DM_PORT           => 1,
      CLK_PERIOD            => CLK_PERIOD
      )
    port map (
      ddr2_dq               => ddr2_dq,
      ddr2_a                => ddr2_a,
      ddr2_ba               => ddr2_ba,
      ddr2_ras_n            => ddr2_ras_n,
      ddr2_cas_n            => ddr2_cas_n,
      ddr2_we_n             => ddr2_we_n,
      ddr2_cs_n             => ddr2_cs_n,
      ddr2_odt              => ddr2_odt,
      ddr2_cke              => ddr2_cke,
      ddr2_dm               => ddr2_dm,
      phy_init_done         => i_phy_init_done,
      rst0                  => rst0,
      rst90                 => rst90,
      rstdiv0               => rstdiv0,
      clk0                  => clk0,
      clk90                 => clk90,
      clkdiv0               => clkdiv0,
      app_wdf_afull         => app_wdf_afull,
      app_af_afull          => app_af_afull,
      rd_data_valid         => rd_data_valid,
      app_wdf_wren          => app_wdf_wren,
      app_af_wren           => app_af_wren,
      app_af_addr           => app_af_addr,
      app_af_cmd            => app_af_cmd,
      rd_data_fifo_out      => rd_data_fifo_out,
      app_wdf_data          => app_wdf_data,
      app_wdf_mask_data     => app_wdf_mask_data,
      ddr2_dqs              => ddr2_dqs,
      ddr2_dqs_n            => ddr2_dqs_n,
      ddr2_ck               => ddr2_ck,
      rd_ecc_error          => open,
      ddr2_ck_n             => ddr2_ck_n,

      dbg_calib_done          => dbg_calib_done,
      dbg_calib_err           => dbg_calib_err,
      dbg_calib_dq_tap_cnt    => dbg_calib_dq_tap_cnt,
      dbg_calib_dqs_tap_cnt   => dbg_calib_dqs_tap_cnt,
      dbg_calib_gate_tap_cnt   => dbg_calib_gate_tap_cnt,
      dbg_calib_rd_data_sel   => dbg_calib_rd_data_sel,
      dbg_calib_rden_dly      => dbg_calib_rden_dly,
      dbg_calib_gate_dly      => dbg_calib_gate_dly,
      dbg_idel_up_all         => dbg_idel_up_all,
      dbg_idel_down_all       => dbg_idel_down_all,
      dbg_idel_up_dq          => dbg_idel_up_dq,
      dbg_idel_down_dq        => dbg_idel_down_dq,
      dbg_idel_up_dqs         => dbg_idel_up_dqs,
      dbg_idel_down_dqs       => dbg_idel_down_dqs,
      dbg_idel_up_gate        => dbg_idel_up_gate,
      dbg_idel_down_gate      => dbg_idel_down_gate,
      dbg_sel_idel_dq         => dbg_sel_idel_dq,
      dbg_sel_all_idel_dq     => dbg_sel_all_idel_dq,
      dbg_sel_idel_dqs        => dbg_sel_idel_dqs,
      dbg_sel_all_idel_dqs    => dbg_sel_all_idel_dqs,
      dbg_sel_idel_gate       => dbg_sel_idel_gate,
      dbg_sel_all_idel_gate   => dbg_sel_all_idel_gate
      );


  u_ddr2_tb_top_0 : ddr2_tb_top
    generic map (
      BANK_WIDTH            => BANK_WIDTH,
      COL_WIDTH             => COL_WIDTH,
      DM_WIDTH              => DM_WIDTH,
      DQ_WIDTH              => DQ_WIDTH,
      ROW_WIDTH             => ROW_WIDTH,
      BURST_LEN             => BURST_LEN,
      ECC_ENABLE            => ECC_ENABLE,
      APPDATA_WIDTH         => APPDATA_WIDTH
      )
    port map (
      phy_init_done         => i_phy_init_done,
      error                 => i_error,
      error_cmp             => error_cmp,
      rst0                  => rst0,
      clk0                  => clk0,
      app_wdf_afull         => app_wdf_afull,
      app_af_afull          => app_af_afull,
      rd_data_valid         => rd_data_valid,
      app_wdf_wren          => app_wdf_wren,
      app_af_wren           => app_af_wren,
      app_af_addr           => app_af_addr,
      app_af_cmd            => app_af_cmd,
      rd_data_fifo_out      => rd_data_fifo_out,
      app_wdf_data          => app_wdf_data,
      app_wdf_mask_data     => app_wdf_mask_data
      );

  --*****************************************************************
  -- Hooks to prevent sim/syn compilation errors (mainly for VHDL - but
  -- keep it also in Verilog version of code) w/ floating inputs if
  -- DEBUG_EN = 0.
  --*****************************************************************

  gen_dbg_tie_off: if (DEBUG_EN = 0) generate
    dbg_idel_up_all       <= '0';
    dbg_idel_down_all     <= '0';
    dbg_idel_up_dq        <= '0';
    dbg_idel_down_dq      <= '0';
    dbg_idel_up_dqs       <= '0';
    dbg_idel_down_dqs     <= '0';
    dbg_idel_up_gate      <= '0';
    dbg_idel_down_gate    <= '0';
    dbg_sel_idel_dq       <= (others => '0');
    dbg_sel_all_idel_dq   <= '0';
    dbg_sel_idel_dqs      <= (others => '0');
    dbg_sel_all_idel_dqs  <= '0';
    dbg_sel_idel_gate     <= (others => '0');
    dbg_sel_all_idel_gate <= '0';

  end generate;

  gen_dbg_tie_on: if (DEBUG_EN = 1) generate
   
      --*****************************************************************
      -- Bit assignments:
      -- NOTE: Not all VIO, ILA inputs/outputs may be used - these will
      --       be dependent on the user's particular bit width
      --*****************************************************************

      gen_dq_le_32: if (DQ_WIDTH <= 32) generate
        vio0_in((6*DQ_WIDTH)-1 downto 0) <= 
	                    dbg_calib_dq_tap_cnt((6*DQ_WIDTH)-1 downto 0);
      end generate;

      gen_dq_gt_32: if (DQ_WIDTH > 32) generate 
        vio0_in <= dbg_calib_dq_tap_cnt(191 downto 0);
      end generate;

      gen_dqs_le_8: if (DQS_WIDTH <= 8) generate
        vio1_in((6*DQS_WIDTH)-1 downto 0) <= 
	                    dbg_calib_dqs_tap_cnt((6*DQS_WIDTH)-1 downto 0);
        vio1_in((12*DQS_WIDTH)-1 downto (6*DQS_WIDTH)) <=
	                    dbg_calib_gate_tap_cnt((6*DQS_WIDTH)-1 downto 0);
      end generate;
      
      gen_dqs_gt_8: if (DQS_WIDTH > 8) generate
        vio1_in(47 downto 0) <= dbg_calib_dqs_tap_cnt(47 downto 0);
        vio1_in(95 downto 48) <= dbg_calib_gate_tap_cnt(47 downto 0);
      end generate;
 
      --dbg_calib_rd_data_sel

      gen_rdsel_le_8: if (DQS_WIDTH <= 8) generate
        vio2_in((DQS_WIDTH)+7 downto 8) <= 
	                    dbg_calib_rd_data_sel((DQS_WIDTH)-1 downto 0);
      end generate;
      gen_rdsel_gt_8: if (DQS_WIDTH > 8) generate
        vio2_in(15 downto 8) <= dbg_calib_rd_data_sel(7 downto 0);
      end generate;
 
      --dbg_calib_rden_dly

      gen_calrd_le_8: if (DQS_WIDTH <= 8) generate
        vio2_in((5*DQS_WIDTH)+19 downto 20) <= 
	                    dbg_calib_rden_dly((5*DQS_WIDTH)-1 downto 0);
      end generate; 
     
      gen_calrd_gt_8: if (DQS_WIDTH > 8) generate
        vio2_in(59 downto 20) <= dbg_calib_rden_dly(39 downto 0);
      end generate;

      --dbg_calib_gate_dly

      gen_calgt_le_8: if (DQS_WIDTH <= 8) generate
        vio2_in((5*DQS_WIDTH)+59 downto 60) <= 
	                    dbg_calib_gate_dly((5*DQS_WIDTH)-1 downto 0);
      end generate; 

      gen_calgt_gt_8: if (DQS_WIDTH > 8) generate
        vio2_in(99 downto 60) <= dbg_calib_gate_dly(39 downto 0);
      end generate;

      --dbg_sel_idel_dq

      gen_selid_le_5: if (DQ_BITS <= 5) generate
        dbg_sel_idel_dq(DQ_BITS-1 downto 0) <= vio3_out(DQ_BITS+7 downto 8);
      end generate;
      
      gen_selid_gt_5: if (DQ_BITS > 5) generate
        dbg_sel_idel_dq(4 downto 0) <= vio3_out(12 downto 8);
      end generate;

      --dbg_sel_idel_dqs

      gen_seldqs_le_3: if (DQS_BITS <= 3) generate
        dbg_sel_idel_dqs(DQS_BITS downto 0) <= 
	                    vio3_out((DQS_BITS+16) downto 16);
      end generate;
      
      gen_seldqs_gt_3: if (DQS_BITS > 3) generate
        dbg_sel_idel_dqs(3 downto 0) <= vio3_out(19 downto 16);
      end generate;

      --dbg_sel_idel_gate

      gen_gtdqs_le_3: if (DQS_BITS <= 3) generate
        dbg_sel_idel_gate(DQS_BITS downto 0) <= vio3_out((DQS_BITS+21) downto 21);
      end generate;

      gen_gtdqs_gt_3: if (DQS_BITS > 3) generate
        dbg_sel_idel_gate(3 downto 0) <= vio3_out(24 downto 21);
     end generate;

      vio2_in(3 downto 0)              <= dbg_calib_done;
      vio2_in(7 downto 4)       <= dbg_calib_err;
      
      dbg_idel_up_all           <= vio3_out(0);
      dbg_idel_down_all         <= vio3_out(1);
      dbg_idel_up_dq            <= vio3_out(2);
      dbg_idel_down_dq          <= vio3_out(3);
      dbg_idel_up_dqs           <= vio3_out(4);
      dbg_idel_down_dqs         <= vio3_out(5);
      dbg_idel_up_gate          <= vio3_out(6);
      dbg_idel_down_gate        <= vio3_out(7);
      dbg_sel_all_idel_dq       <= vio3_out(15);
      dbg_sel_all_idel_dqs      <= vio3_out(20);
      dbg_sel_all_idel_gate     <= vio3_out(25);

    u_icon  : icon4
    port map (
      control0              => cs_control0,
      control1              => cs_control1,
      control2              => cs_control2,
      control3              => cs_control3
      );

      --*****************************************************************
      -- VIO ASYNC input: Display current IDELAY setting for up to 32
      -- DQ taps (32x6) = 192
      --*****************************************************************

    u_vio0 : vio_async_in192
    port map (
      control               => cs_control0,
      async_in              => vio0_in
      );

      --*****************************************************************
      -- VIO ASYNC input: Display current IDELAY setting for up to 8 DQS
      -- and DQS Gate taps (8x6x2) = 96
      --*****************************************************************

    u_vio1 : vio_async_in96 
    port map (
      control               => cs_control1,
      async_in              => vio1_in
      );

      --*****************************************************************
      -- VIO ASYNC input: Display other calibration results
      --*****************************************************************

    u_vio2 : vio_async_in100 
    port map (
      control               => cs_control2,
      async_in              => vio2_in
      );
      
      --*****************************************************************
      -- VIO SYNC output: Dynamically change IDELAY taps
      --*****************************************************************
      
    u_vio3 : vio_sync_out32 
    port map (
      control               => cs_control3,
      clk                   => clkdiv0,
      sync_out              => vio3_out
      );

  end generate;


-- Tutorial debug insertions --
  MY_DEBUG_ILA: if (MY_DEBUG = 1) generate
    my_data(30 downto 0) <=
            app_af_addr(30 downto 0);
    my_data(63 downto 31) <=
            (others => '0');
    my_data(71 downto 64) <=
            app_wdf_afull &
            app_af_afull &
            app_wdf_wren &
            app_af_cmd(0) &
            i_phy_init_done &
            idelay_ctrl_rdy &
            sys_rst_n &
            i_error;
    my_trig0(7 downto 0) <=
            i_phy_init_done &
            idelay_ctrl_rdy &
            sys_rst_n &
            i_error &
            app_wdf_afull &
            app_af_afull &
            app_wdf_wren &
            app_af_cmd(0);
    my_icon  : micon_1
    port map (
        CONTROL0              => my_control
      );
    my_ila  : mila
    port map (
        CLK                   => clk0,
        CONTROL               => my_control,
        TRIG0                 => my_trig0,
        DATA                  => my_data
      );
  end generate;
-- Tutorial debug insertions --

end architecture arc_mem_interface_top;

