`timescale 1ns/1ps

module SRAM #(
  parameter LOGIC_CLK_FEEDBACK=0, SRAM_CLK_FEEDBACK=0,
              SRAM_CLK_ODDR=1 //Clock-Forwarding via ODDR (Xilinx-recommended)
)(
  // Clocks, Locks & two smoking Resets
  input         clock_base,     //Reference for internal clock generation
  input         reset,          //Active-HI reset (logic & clocks)
  output        logic_clk_g,    //Controller/arbiter clock (FPGA logic)
  output        locked,         //Clocks sync'd (cascade to other clock reset/lock)

  // Application Interface (clock @posedge logic_clk_g)
  output        ready,          //Ready for requests (asserted immediately after clock)
  input         addr_valid,     //Initiate READ/WRITE request
  input  [17:0] addr,           //256K words (1MB addressible)
  input  [35:0] data_in,        //Data to queue for WRITE
  input  [ 3:0] write_mask,     //Active-HI BYTE-WRITEMASK (or READ if all LO)
  output        data_out_valid, //Asserted 3-cycles after READ request
  output [35:0] data_out,       //Registered copy of data to/from SRAM

  // Physical Interface (to PADs, clock @SRAM_CLK)
  input         SRAM_CLK_FB,
  output        SRAM_CLK,
  output        SRAM_CS_L,
  output        SRAM_WE_L,
  output        SRAM_MODE,
  output        SRAM_ADV_LD_L,
  output        SRAM_OE_L,
  inout  [35:0] SRAM_DATA,
  output [17:0] SRAM_ADDR,
  output [ 3:0] SRAM_BW_L
);


// SRAM CONTROLLER & DATAPATH:

// Shift-Registers (# of "r"s indicates delay cycles, CAPS indicate IOBs)
//  NEED-IOB        width  T1,        T2,         T3,         T4         ;
(*IOB="FORCE"*) reg [17:0] addr_R                                        ;
(*IOB="FORCE"*) reg [ 3:0] bw_R                                          ;
(*IOB="FORCE"*) reg        we_R                                          ;
                reg        addrv_r,   readv_rr,   readv_rrr,  readv_rrrr ;
                reg        tri01_r                                       ;
(*keep="TRUE"*) reg [ 4:0]                        rd05v_rrr              ;
(*keep="TRUE"*) reg [ 3:0]            tri04_rr                           ;
(*IOB="FORCE"*) reg [35:0]                        tri36_RRR,  rdata_RRRR ;
(*IOB="FORCE"*) reg [35:0]                        wdata_RRR              ;
(*keep="TRUE"*) reg [35:0]            wdata_rr                           ;
                reg [35:0] wdata_r                                       ;
//NOTE: Brute-force IOB packing may not always be best, but using it here.
//      "FORCE" triggers error if the register is not packed. KEEP and
//      "equivalent_register_removal" try to preserve the INST/NET.
//ALTERNATE: (*keep="TRUE",equivalent_register_removal="NO",IOB="TRUE"*)
//synthesis attribute keep of addr_R is "TRUE"
//synthesis attribute keep of bw_R is "TRUE"
//synthesis attribute keep of we_R is "TRUE"
//synthesis attribute keep of tri36_RRR is "TRUE"
//synthesis attribute keep of wdata_RRR is "TRUE"
//synthesis attribute keep of rdata_RRRR is "TRUE"
//synthesis attribute equivalent_register_removal of addr_R is "NO"
//synthesis attribute equivalent_register_removal of bw_R is "NO"
//synthesis attribute equivalent_register_removal of we_R is "NO"
//synthesis attribute equivalent_register_removal of tri36_RRR is "NO"
//synthesis attribute equivalent_register_removal of wdata_RRR is "NO"
//synthesis attribute equivalent_register_removal of rdata_RRRR is "NO"
//synthesis attribute IOB of addr_R is "TRUE"
//synthesis attribute IOB of bw_R is "TRUE"
//synthesis attribute IOB of we_R is "TRUE"
//synthesis attribute IOB of tri36_RRR is "TRUE"
//synthesis attribute IOB of wdata_RRR is "TRUE"
//synthesis attribute IOB of rdata_RRRR is "FALSE"

// --guard the wee register trees preceeding READ/WRITE REGs/IOBs--
//synthesis attribute equivalent_register_removal of tri04_rr is "NO"
//synthesis attribute equivalent_register_removal of rd05v_rrr is "NO"
//synthesis attribute equivalent_register_removal of wdata_rr is "NO"
//synthesis attribute keep of tri04_rr is "TRUE"
//synthesis attribute keep of rd05v_rrr is "TRUE"
//synthesis attribute keep of wdata_rr is "TRUE"


  // Application I/O (bw_l & we_l logic gets absorbed/optimized into arbiter/controller)
  reg        ready_r;
  wire [3:0] bw_l = (addr_valid) ? ~write_mask : 4'hF; //Active-lo BYTE-WRITEMASK
  wire       we_l = !(ready_r && addr_valid && |write_mask); //Active-lo WRITE-ENABLE
  assign ready = ready_r;
  assign data_out = rdata_RRRR;
  assign data_out_valid = readv_rrrr;

  // Physical I/O
  assign SRAM_CS_L      = 0; //T?: Always enable SRAM via CHIP-SELECT
  assign SRAM_MODE      = 0; //T?: INTERLEAVE/LINEAR burst MODE unused
  assign SRAM_ADV_LD_L  = 0; //T1: ADVANCE/LOAD always LOAD address
  assign SRAM_OE_L      = 0; //T?: Always OUTPUT-ENABLE, chip still tri-states ITSELF as needed
  assign SRAM_ADDR = addr_R; //T1: READ/WRITE address (even if invalid, for less logic)
  assign SRAM_BW_L = bw_R;   //T1: Active-lo BYTE-WRITEMASK (data catches up on T3)
  assign SRAM_WE_L = we_R;   //T1: Active-lo WRITE-ENABLE (else is READ)
  wire [35:0] rdata_www;
  genvar iB; generate for (iB=0; iB<36; iB=iB+1) begin:_SRAM_DATA_IOB_
  //assign SRAM_DATA[iB] = tri36_RRR[iB] ? 36'dz : wdata_RRR[iB]; //T3: Driven only on WRITE
    IOBUF iobuf_data(
      .I (wdata_RRR[iB]), .T(tri36_RRR[iB]), //T3: Driven only on WRITE
      .IO(SRAM_DATA[iB]), .O(rdata_www[iB])
    );
  //KEEPER keepit( .O(SRAM_DATA[iB]) ); //This helps to exaggerate missing data
  end endgenerate //Per-bit "assign" & tri36-tree helps registers pack into IOBUFs

  // Coordinate with SRAM pipeline via patchwork of shifted drives/reads on appropriate cycle
  always @(posedge logic_clk_g) begin
    if (!locked) begin //Only critical registers bother with "reset"
      ready_r <= 0;
      {addrv_r, readv_rr, readv_rrr, readv_rrrr} <= 0;
    end else begin
      ready_r <= 1'b1; //Announce ready

      //T1<=T0 (drive SRAM pipeline & feed head of our shift-registers)
      {addr_R, we_R, bw_R} <= {addr, we_l, bw_l}; //Drive SRAM with newest request
      {wdata_r,   tri01_r,   addrv_r   } <= {data_in,  we_l,          addr_valid };

      //T2<=T1 (shifting, wee-tree growing, resolve readv_rr other signals)
      {wdata_rr,  tri04_rr,  readv_rr  } <= {wdata_r,  {4{tri01_r}}, (tri01_r && addrv_r)};

      //T3<=T2 (setup potential WRITE at end of T3, grow our wee-trees more)
      {wdata_RRR, tri36_RRR, readv_rrr } <= {wdata_rr, {9{tri04_rr}}, readv_rr   };
      rd05v_rrr <= {5{readv_rr}};

      //T4<=T3 (capture potential READ from T3)
      readv_rrrr <= readv_rrr; //readv_rrr & rd05v_rrr[n] are identical (from wee-tree)
      if (rd05v_rrr[4]) rdata_RRRR[35:32] <= rdata_www[35:32]; //SRAM_DATA[...]
      if (rd05v_rrr[3]) rdata_RRRR[31:24] <= rdata_www[31:24];
      if (rd05v_rrr[2]) rdata_RRRR[23:16] <= rdata_www[23:16];
      if (rd05v_rrr[1]) rdata_RRRR[15: 8] <= rdata_www[15: 8];
      if (rd05v_rrr[0]) rdata_RRRR[ 7: 0] <= rdata_www[ 7: 0];
    end
  end


// CLOCK MANAGEMENT:

//TODO: Local reset chain for isolation
  wire locked_logic, locked_sram;
  wire logic_clk_pre, clk_sram_g;

  assign locked = !reset && locked_logic && locked_sram;

  BUFG bufg_logic_clk( .I(logic_clk_pre), .O(logic_clk_g) );

  wire reset_base = 1'b0; //Used for optional clock-sync DLLs
//  reg [3:0] reset_base_r = 4'b1111;

generate if (SRAM_CLK_ODDR) begin:_WITH_SRAM_ODDR_
  wire clk_sram_oddr;
  ODDR #(
    .INIT(1'b0), .DDR_CLK_EDGE("OPPOSITE_EDGE"), .SRTYPE("SYNC")
  ) oddr_SRAM_CLK (
    .Q(clk_sram_oddr),
    .CE (1'b1), .R(1'b0), .S(1'b0),
    .C(clk_sram_g),
    .D1(1'b1), .D2(1'b0));
  //NOTE:OFDDRRSE output must feed direct & solo to its OBUF
  assign SRAM_CLK = clk_sram_oddr; //OBUF must be created elsewhere or automatically
end else begin:_NO_SRAM_ODDR_
  assign SRAM_CLK = clk_sram_g; //OBUF likely created automatically, as appropriate
end endgenerate

generate if (LOGIC_CLK_FEEDBACK) begin:_WITH_LOGIC_FB_
  DCM #(
    .DLL_FREQUENCY_MODE("HIGH"), .DESKEW_ADJUST("SYSTEM_SYNCHRONOUS")
  ) dcm_logic_clk (
    .CLKIN(clock_base), .RST(reset_base || reset), .LOCKED(locked_logic),
    .CLK0 (logic_clk_pre), .CLKFB(logic_clk_g) );
end else begin:_NO_LOGIC_FB_
  assign logic_clk_pre = clock_base,
          locked_logic = !reset;
end endgenerate


generate if (SRAM_CLK_FEEDBACK) begin:_WITH_SRAM_FB_
  wire clk_sram_pre, clk_sram_fb;
  IBUFG ibufg_sram_fb( .I(SRAM_CLK_FB), .O(clk_sram_fb) );
  //NOTE:If CLKIN/CLKFB not identical I/O buffers, might not be ideal
  DCM #(
    .DLL_FREQUENCY_MODE("HIGH"), .DESKEW_ADJUST("SOURCE_SYNCHRONOUS")
  ) dcm_clk_sram(
    .CLKIN(clock_base), .RST(reset_base || reset), .LOCKED(locked_sram),
    .CLK0(clk_sram_pre), .CLKFB(clk_sram_fb));
  BUFG bufg_clk_sram( .I(clk_sram_pre), .O(clk_sram_g) );
end else begin:_NO_SRAM_FB_
  assign clk_sram_g = logic_clk_g,
          locked_sram = locked_logic;
end endgenerate

endmodule
