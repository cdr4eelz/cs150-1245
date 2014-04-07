module ml505top #(
    parameter CPU_FREQ = 50_000_000,
    parameter COLT45_STALLDIP=1
)(
    // Reference Clock (100MHz) & board reset
    input         USER_CLK,
    input         FPGA_CPU_RESET_B,

    // SERIAL (UART)
    input         FPGA_SERIAL1_RX,
    output        FPGA_SERIAL1_TX,

    // GPIO (SWitches & LEDs)
    input   [7:0] GPIO_DIP,
    output  [7:0] GPIO_LED,
    input   [4:0] GPIO_COMPPB,  // [4:0] is [CWESN]
    output  [4:0] GPIO_COMPLED, // [4:0] is [CWESN]
    input         FPGA_ROTARY_INCA, FPGA_ROTARY_INCB, FPGA_ROTARY_PUSH,
    output        BUS_ERROR_1, BUS_ERROR_2,  //RED

    // DDR via MIG
    output [12:0] DDR2_A,
    output  [1:0] DDR2_BA,
    output        DDR2_CAS_B,
    output        DDR2_CKE0,
    output  [1:0] DDR2_CLK_N,
    output  [1:0] DDR2_CLK_P,
    output        DDR2_CS0_B,
    inout  [63:0] DDR2_D,
    output  [7:0] DDR2_DM,
    inout   [7:0] DDR2_DQS_N,
    inout   [7:0] DDR2_DQS_P,
    output        DDR2_ODT0,
    output        DDR2_RAS_B,
    output        DDR2_WE_B,

    // DVI Controller
    output [11:0] DVI_D,
    output        DVI_DE,
    output        DVI_H,
    output        DVI_RESET_B,
    output        DVI_V,
    output        DVI_XCLK_N,
    output        DVI_XCLK_P,
    inout         IIC_SCL_VIDEO,
    inout         IIC_SDA_VIDEO,

    // ZBT SRAM Controller
    input         SRAM_CLK_FB,
    output        SRAM_CLK,
    output        SRAM_WE_B,
    output        SRAM_CS_B,
    output        SRAM_ADV_LD_B,
    output        SRAM_MODE,
    output        SRAM_OE_B,
    output  [3:0] SRAM_BW,
    output [17:0] SRAM_A,
    inout  [35:0] SRAM_D, //4-bits of parity tacked on

    // VGA Capture
    input   [7:0] VGA_RED, VGA_GREEN, VGA_BLUE,
    input         VGA_DATA_CLK,
    input         VGA_HSOUT,
    input         VGA_VSOUT
);

//Declare a couple custom signals & rename GPIO
wire any_stall /* synthesis syn_maxfan = 10 */;
// synthesis attribute max_fanout of any_stall is 10

//IO hookups
wire GPIO_SW_C;
assign GPIO_COMPLED = GPIO_COMPPB; //Compass LED lights mimic pushbuttons
assign GPIO_SW_C = GPIO_COMPPB[4];
assign BUS_ERROR_1 = FPGA_CPU_RESET_B;
assign BUS_ERROR_2 = !FPGA_CPU_RESET_B;
wire [31:0] DBG_MEM150;

    // Clocking (PLL/DCM/DLL) wires
    wire user_clk_g, pll_lock, init_done;
    wire cpu_clk_g, dvi_clk_g, clk200_g, clk0_g, clk90_g, clkdiv0_g;
    // Resets named rst_{CLK-DOMAIN}_{RST-STAGE}
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE" *)
    reg  rst_user_pll /* synthesis syn_maxfan = 10 */;
// synthesis attribute max_fanout of rst_user_pll is 10
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE" *)
    reg  rst_cpu_mem, rst_cpu_bus, rst_cpu_cpu /* synthesis syn_maxfan = 10 */;
// synthesis attribute max_fanout of rst_cpu_mem is 10
// synthesis attribute max_fanout of rst_cpu_bus is 10
// synthesis attribute max_fanout of rst_cpu_cpu is 10
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE" *)
    reg  rst_dvi_bus /* synthesis syn_maxfan = 10 */;
// synthesis attribute max_fanout of rst_dvi_bus is 10

    // Memory150
    wire [31:0] dcache_addr,    icache_addr;
    wire [ 3:0] dcache_we,      icache_we;
    wire        dcache_re,      icache_re;
    wire [31:0] dcache_din,     icache_din;
    wire [31:0] dcache_dout,    icache_dout;
    wire        stall;
    wire        video_ready;
    wire        video_valid;
    wire [23:0] video;
    wire [31:0] pf_frame;
    wire        pf_valid;
    wire        frame_interrupt;
    wire [31:0] gp_code;
    wire [31:0] gp_frame;
    wire        gp_valid;
    wire        gp_interrupt;
    wire [31:0] graphics_status;
//  wire        fb0; ???Was this like pf_frame???


//TODO:Use debouncer module on all buttons
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF",
       ASYNC_REG="TRUE", OPTIMIZE="OFF", RLOC="X0Y0" *)
    reg  [ 3:0] reset_r;
    always @(posedge user_clk_g) begin
        reset_r <= {reset_r[2:0], GPIO_SW_C}; //Synchronize external button signal
    end

//TODO:Move PLL & RESETs to module (maybe same as TestBenches use)
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF",
       ASYNC_REG="TRUE", OPTIMIZE="OFF", RLOC="X0Y1" *)
    reg  [ 3:0] reset_advance; //A wee synchronization & debounce FF-chain

    reg  [ 7:0] reset_count, reset_delay; //Count range for short delay
    reg  [ 2:0] reset_stage = 0; //Numeric stage representation

    wire [ 7:0] reset_lines = (8'hFF << reset_stage); //Shifting-HOT representation
    wire [ 7:0] reset_watch_table = { //Criteria for advancing stage
                    4'd0, 1'b1, init_done, pll_lock, 1'b1 };
    wire reset_watch = (reset_watch_table >> reset_stage);

    always @(posedge user_clk_g) begin
        if ({pll_lock,reset_lines[1:0]} == 3'b000) begin //First 2 stages bootstrap pll_lock
            {reset_stage, reset_advance, reset_count, reset_delay} <= 0;
        end else begin
            if (&reset_advance) begin
                reset_stage <= reset_stage + 1;
                reset_count <= reset_delay;
                //TODO: Update reset_delay
                reset_advance <= 0;
            end else begin
                reset_count <= reset_count - 1;
                reset_advance <= {reset_advance[2:0], reset_watch};
            end
        end
    end

//TODO:Make a mini reset "tree" for distribution (within each domain)
    always @(*) rst_user_pll = reset_lines[0] || (&reset_r); //USER-clock (already)
    always @(posedge cpu_clk_g) begin //CPU-clock
        rst_cpu_mem <= reset_lines[1];
        rst_cpu_bus <= reset_lines[2];
        rst_cpu_cpu <= reset_lines[3];
    end
    always @(posedge dvi_clk_g) begin //DVI-clock
        rst_dvi_bus <= reset_lines[2];
    end


    Memory150 #(
        .SIM_ONLY(1'b0)
    ) mem_arch (
    // Clocks & Resets:
        .cpu_clk_g  (cpu_clk_g),
        .dvi_clk_g  (dvi_clk_g),
        .clk200_g   (clk200_g),
        .clk0_g     (clk0_g),
        .clkdiv0_g  (clkdiv0_g),
        .clk90_g    (clk90_g),
        .locked     (pll_lock),
        .init_done  (init_done),
        .rst_cpu_mem(rst_cpu_mem),
        .rst_cpu_bus(rst_cpu_bus),
        .rst_dvi_bus(rst_dvi_bus),
    // DDR2 pads:
        .DDR2_A     (DDR2_A),
        .DDR2_BA    (DDR2_BA),
        .DDR2_CAS_B (DDR2_CAS_B),
        .DDR2_CKE   (DDR2_CKE0),
        .DDR2_CLK_N (DDR2_CLK_N),
        .DDR2_CLK_P (DDR2_CLK_P),
        .DDR2_CS_B  (DDR2_CS0_B),
        .DDR2_D     (DDR2_D),
        .DDR2_DM    (DDR2_DM),
        .DDR2_DQS_N (DDR2_DQS_N),
        .DDR2_DQS_P (DDR2_DQS_P),
        .DDR2_ODT   (DDR2_ODT0),
        .DDR2_RAS_B (DDR2_RAS_B),
        .DDR2_WE_B  (DDR2_WE_B),
    // Cache <=> CPU interface:
        .dcache_addr(dcache_addr),
        .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),
        .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),
        .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),
        .icache_din (icache_din ),
        .dcache_dout(dcache_dout),
        .icache_dout(icache_dout),
        .stall      (stall      ),
    // DVI driver:
        .video_ready    (video_ready    ),
        .video_valid    (video_valid    ),
        .video          (video          ),
    // Graphics <=> CPU interface:
        .graphics_status(graphics_status),
        .cpu_pf_valid   (pf_valid       ),
        .cpu_pf_frame   (pf_frame       ),
        .frame_interrupt(frame_interrupt),
        .cpu_gp_valid   (gp_valid       ),
        .cpu_gp_frame   (gp_frame       ),
        .cpu_gp_code    (gp_code        ),
        .gp_interrupt   (gp_interrupt   ),
// Chipscope cross-module tap
.DBG_MEM150(DBG_MEM150)
    );


// Memory/IO lines (snagged from MIPS150)
    wire  [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire  [31: 0] IMEM_DATA, DMEM_DATA;
    wire  [31: 0] _WDataMasked;
    wire  [ 3: 0] _WriteMask;
    wire  MemToRegDX_, MemWriteDX_, PCinBIOSDX_;
    wire  [31: 0] MemAddr_MW;
    wire  [31: 0] CNT_Cycle, CNT_Inst;

    // Memory Bank & Memory Mapped I/O
    MIPS150 #(
        .CPU_FREQ(CPU_FREQ)
    ) CPU (
        .clk(cpu_clk_g),
        .rst(rst_cpu_cpu),
    // Memory/IO <==> MemBank
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_), .MemAddr_MW(MemAddr_MW),
        .CNT_Cycle(CNT_Cycle), .CNT_Inst(CNT_Inst),
// Chipscope cross-module tap:
.DBG_MEM150(DBG_MEM150)
    );

    // MIPS 150 CPU
    MemBank #(
        .CPU_FREQ(CPU_FREQ)
    ) mem_bank (
        .clk(cpu_clk_g),
        .rst(rst_cpu_cpu),
    // Memory/IO <==> MIPS150
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_), .MemAddr_MW(MemAddr_MW),
        .CNT_Cycle(CNT_Cycle), .CNT_Inst(CNT_Inst),
    // Serial (UART):
        .FPGA_SERIAL_RX(FPGA_SERIAL1_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL1_TX),
    // Memory Caches:
        .dcache_addr (dcache_addr),
        .icache_addr (icache_addr),
        .dcache_we   (dcache_we  ),
        .icache_we   (icache_we  ),
        .dcache_re   (dcache_re  ),
        .icache_re   (icache_re  ),
        .dcache_din  (dcache_din ),
        .icache_din  (icache_din ),
        .dcache_dout (dcache_dout),
        .icache_dout (icache_dout),
        .stall       (any_stall  ),
    // Graphics:
        .graphics_status(graphics_status),
        .pf_valid       (pf_valid),
        .pf_frame       (pf_frame),
        .frame_interrupt(frame_interrupt),
        .gp_valid       (gp_valid),
        .gp_frame       (gp_frame),
        .gp_code        (gp_code),
        .gp_interrupt   (gp_interrupt)
    );

//RESOLUTION:          Width FrontH PulseH BackH Height FrontV PulseV BackV ClockFreq
//  VGA  640x480@60Hz:  800    16     96    48    525     10      2    33    25175000
// VESA  800x600@72Hz: 1040    56    120    64    666     37      6    23    50000000
// VESA 1024x768@70Hz: 1328    24    136   144    806      3      6    29    75000000
    DVI #(
//      .Width ( 800), .FrontH( 16), .PulseH( 96), .BackH( 48), //  VGA  640x480@60Hz
//      .Height( 525), .FrontV( 10), .PulseV(  2), .BackV( 33), .ClockFreq(25_175_000)
        .Width (1040), .FrontH( 56), .PulseH(120), .BackH( 64), // VESA  800x600@72Hz
        .Height( 666), .FrontV( 37), .PulseV(  6), .BackV( 23), .ClockFreq(50_000_000)
//      .Width (1328), .FrontH( 24), .PulseH(136), .BackH(144), // VESA 1024x768@70Hz
//      .Height( 806), .FrontV(  3), .PulseV(  6), .BackV( 29), .ClockFreq(75_000_000)
    ) dvi (
        .Clock(dvi_clk_g), .Reset(rst_dvi_bus), .DVI_RESET_B(DVI_RESET_B),
        .DVI_D(DVI_D), .DVI_DE(DVI_DE), .DVI_H(DVI_H), .DVI_V(DVI_V), //Data,Ena,Hor,Ver
        .DVI_XCLK_N(DVI_XCLK_N), .DVI_XCLK_P(DVI_XCLK_P),         //Differential clock
        .I2C_SCL_DVI(IIC_SCL_VIDEO), .I2C_SDA_DVI(IIC_SDA_VIDEO), //Configuration IIC
        .VideoReady(video_ready), //Ready/Valid interface for 24-bit pixel RGB feed
        .VideoValid(video_valid), .Video(video)
    );

    wire cpu_clk, dvi_clk, clk200, clk0, clk90, clkdiv0, pll_fb;
    PLL_BASE #(
        .CLKIN_PERIOD(  10.0), .CLKFBOUT_PHASE(0.0),
        .CLKFBOUT_MULT( 24),
        .DIVCLK_DIVIDE(  4),
        .BANDWIDTH("OPTIMIZED"),
        .CLKOUT0_DIVIDE(12),    .CLKOUT0_PHASE(  0.0),  .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DIVIDE(12),    .CLKOUT1_PHASE( 45.0),  .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DIVIDE( 3),    .CLKOUT2_PHASE(  0.0),  .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT3_DIVIDE( 3),    .CLKOUT3_PHASE(  0.0),  .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT4_DIVIDE( 3),    .CLKOUT4_PHASE( 90.0),  .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT5_DIVIDE( 6),    .CLKOUT5_PHASE(  0.0),  .CLKOUT5_DUTY_CYCLE(0.5),
        .COMPENSATION("SYSTEM_SYNCHRONOUS"), .REF_JITTER(0.100)
    ) user_clk_pll (
        .CLKIN(user_clk_g), .RST(rst_user_pll), .LOCKED(pll_lock),
        .CLKOUT0(cpu_clk),
        .CLKOUT1(dvi_clk),
        .CLKOUT2(clk200),
        .CLKOUT3(clk0),
        .CLKOUT4(clk90),
        .CLKOUT5(clkdiv0),
        .CLKFBIN(pll_fb),   .CLKFBOUT(pll_fb)
    );
    IBUFG user_clk_buf ( .I(USER_CLK), .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
    BUFG  dvi_clk_buf  ( .I(dvi_clk),  .O(dvi_clk_g)  );
    BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
    BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
    BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
    BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );


`ifndef COLT45_KILLFUN //Mostly to trigger text editor to hide this whole mess!

//Minor mods for debug (like old dip stall toggle from prior checkpoint)

generate if (COLT45_STALLDIP) begin:_STALL_DIP_
    wire stall_toggle;
    Debouncer #(
        .Width(16) // 2^16 / 50MHz => apprx 1.3 ms?
    ) togglestall_debone (
        .Clock(cpu_clk_g),
        .Reset(rst_cpu_bus),
        .Enable(1'b1),
        .In(GPIO_DIP[0]),
        .Out(stall_toggle)
    );

    reg man_stall_reg; //TODO: Upgrade to "stall ring" from testbenches
    always@(posedge cpu_clk_g) begin:_MAN_STALL_REG_
        if(rst_cpu_bus) begin
            man_stall_reg <= 1'b0;
        end else if (stall_toggle) begin
            man_stall_reg <= ~man_stall_reg;
        end else begin
            man_stall_reg <= 1'b0;
        end
    end

    assign any_stall = stall || man_stall_reg;
    assign GPIO_LED = {3'b0, stall_toggle, any_stall,
                             stall, pll_lock, init_done};
end else begin:_STALL_MEMONLY_
    assign any_stall = stall;
    assign GPIO_LED = {5'b0, stall, pll_lock, init_done};
end endgenerate


//CROSS: SRAM driver from FALL13
  // -- |SRAM Controller| ------------------------------------------------------
  `define SRAM_ENABLE

  wire sram_clock, sram_locked, sram_ready, sram_addr_valid, sram_data_out_valid;
  wire [17:0] sram_addr;
  wire [ 3:0] sram_write_mask;
  wire [35:0] sram_data_in,sram_data_out;

  `ifdef SRAM_ENABLE
    SRAM sram (
      .clock_base(cpu_clk_g),
      .reset(!pll_lock),
      .logic_clk_g(sram_clock),
      .locked(sram_locked),

      .ready(sram_ready),
      .addr_valid(sram_addr_valid),
      .addr(sram_addr),
      .data_in(sram_data_in),
      .write_mask(sram_write_mask),
      .data_out_valid(sram_data_out_valid),
      .data_out(sram_data_out),

      .SRAM_CLK_FB  (SRAM_CLK_FB),
      .SRAM_CLK     (SRAM_CLK),
      .SRAM_CS_L    (SRAM_CS_B),
      .SRAM_WE_L    (SRAM_WE_B),
      .SRAM_MODE    (SRAM_MODE),
      .SRAM_ADV_LD_L(SRAM_ADV_LD_B),
      .SRAM_OE_L    (SRAM_OE_B),
      .SRAM_DATA    (SRAM_D),
      .SRAM_ADDR    (SRAM_A),
      .SRAM_BW_L    (SRAM_BW));
  `else
    assign SRAM_CLK=0;
    assign SRAM_CS_B=1;
    assign SRAM_WE_B=1;
    assign SRAM_MODE=0;
    assign SRAM_ADV_LD_B=1;
    assign SRAM_OE_B=1;
    assign SRAM_D={36{1'bz}};
    assign SRAM_A=0;
    assign SRAM_BW=4'b1111;
  `endif // SRAM_ENABLE

`else
    assign any_stall = stall;
    assign GPIO_LED = {5'b0, stall, pll_lock, init_done};
`endif // COLT45_KILLFUN

endmodule
