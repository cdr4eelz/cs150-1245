module ml505top #(
    parameter CPU_FREQ = 50_000_000,
    parameter COLT45_STALLDIP=1
)(
    // Reference Clock (100MHz) & board reset
    input         USER_CLK,
    input         FPGA_CPU_RESET_B,

    // SERIAL (UART)
    input         FPGA_SERIAL_RX,
    output        FPGA_SERIAL_TX,

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

    //Debug lines
//  wire [31:0] DBG_MEM150; //TODO:Use hierarchical name based "tap" instead

    // Clocking (PLL/DCM/DLL) & Reset & Stall
    wire user_clk_g, pll_lock, init_done, sram_locked;
    wire cpu_clk_g, dvi_clk_g, clk200_g, clk0_g, clk90_g, clkdiv0_g;
    // Distributed resets named rst_{CLK-DOMAIN}_{RST-STAGE}_g
    wire rst_cpu_mem_g, rst_cpu_bus_g, rst_cpu_cpu_g, rst_dvi_bus_g /* synthesis syn_maxfan = 10 */;
        // synthesis attribute max_fanout of rst_cpu_mem_g is 10
        // synthesis attribute max_fanout of rst_cpu_bus_g is 10
        // synthesis attribute max_fanout of rst_cpu_cpu_g is 10
        // synthesis attribute max_fanout of rst_dvi_bus_g is 10
    wire stall_top /* synthesis syn_maxfan = 10 */;
        // synthesis attribute max_fanout of stall_top is 10
    wire toggle_stall, stall_dip, button_reset;

    // Memory150
    wire [31:0] dcache_addr,    icache_addr;
    wire [ 3:0] dcache_we,      icache_we;
    wire        dcache_re,      icache_re;
    wire [31:0] dcache_din,     icache_din;
    wire [31:0] dcache_dout,    icache_dout;
    wire        stall_dcache,   stall_icache; //stall_cache;
    wire        video_ready, video_valid;
    wire [31:0] video;//[23:0]
//  wire        fb0; ???Was this "framebuffer0" like pf_wframe???
    wire        pf_vframe,  gp_vcode, gp_vframe;
    wire [31:0] pf_wframe,  gp_wcode, gp_wframe;
    wire [31:0]             gp_rcode;
    wire [15:0] pf_status,            gp_status;
    wire        irq_pf_frame, irq_gp_done;

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
        .rst_cpu_mem(rst_cpu_mem_g),
        .rst_cpu_bus(rst_cpu_bus_g),
        .rst_dvi_bus(rst_dvi_bus_g),
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
        .dcache_addr(dcache_addr), .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ), .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ), .icache_re  (icache_re  ),
        .dcache_din (dcache_din ), .icache_din (icache_din ),
        .dcache_dout(dcache_dout), .icache_dout(icache_dout),
        .stall  (/*stall_cache*/),
        .d_stall(stall_dcache),    .i_stall(stall_icache),
    // PixelFeeder <=> DVI driver:
        .video_ready    (video_ready),
        .video_valid    (video_valid),
        .video          (video      ),
    // GPU <=> CPU interface:
        .pf_vframe(pf_vframe),  .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),  .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                .gp_rcode(gp_rcode),
        .pf_status(pf_status),                       .gp_status(gp_status),
        .irq_pf_frame(irq_pf_frame), .irq_gp_done(irq_gp_done)
    );


    // MIPS 150 CPU
    MIPS150 #(
        .CPU_FREQ(CPU_FREQ),
        .PC_BOOT(32'h4000_0000)
    ) CPU (
        .clk(cpu_clk_g), .rst(rst_cpu_cpu_g), .stall(stall_top),
    // Serial (UART):
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX), .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    // Memory Caches:
        .dcache_addr(dcache_addr),  .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),  .icache_din (icache_din ),
        .dcache_dout(dcache_dout),  .icache_dout(icache_dout),
    // GPU:
        .pf_vframe(pf_vframe),        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                      .gp_rcode(gp_rcode),
        .pf_status(pf_status),                             .gp_status(gp_status),
        .irq_pf_frame(irq_pf_frame),  .irq_gp_done(irq_gp_done)
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
        .Clock(dvi_clk_g), .Reset(rst_dvi_bus_g),
        .DVI_RESET_B(DVI_RESET_B),                              //Reset Chrontel CH-7301
        .DVI_D(DVI_D), .DVI_DE(DVI_DE), .DVI_H(DVI_H), .DVI_V(DVI_V), //Data,Ena,Hor,Ver
        .DVI_XCLK_N(DVI_XCLK_N), .DVI_XCLK_P(DVI_XCLK_P),           //Differential clock
        .I2C_SCL_DVI(IIC_SCL_VIDEO), .I2C_SDA_DVI(IIC_SDA_VIDEO),    //Configuration IIC
        .VideoReady(video_ready), .VideoValid(video_valid), //Ready/Valid interface...
        .Video(video[23:0]) // ... for 24-bit pixel RGB feed
    );


//TODO:Use debouncer module on all buttons
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF", RLOC="X0Y0" *)
    reg  [ 3:0] reset_r;
    always @(posedge user_clk_g) begin
        reset_r <= {reset_r[2:0], button_reset}; //Synchronize external button signal
    end


//TODO:Move PLL & RESETs to module (maybe same as TestBenches use)
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF", RLOC="X0Y1" *)
    reg  [ 3:0] reset_advance; //A wee synchronization & debounce FF-chain

    reg  [ 7:0] reset_count, reset_delay; //Count range for short delay
    reg  [ 2:0] reset_stage = 0; //Numeric stage representation

    wire [ 7:0] reset_lines = (8'hFF << reset_stage); //Shifting-HOT representation
    wire [ 7:0] reset_watch_table = { //Criteria for advancing stage
                    5'b00001, init_done, pll_lock, 1'b1 };
    wire        reset_watch = (reset_watch_table[reset_stage]);
    wire [ 1:0] reset_bootstrap = {reset_lines[1:0]}; //First 2 stages bootstrap pll_lock

    always @(posedge user_clk_g) begin
        if (!pll_lock && (~|reset_bootstrap)) begin //Lost lock but not bootstrap stages
            {reset_stage, reset_advance, reset_count, reset_delay} <= 0;
        end else begin
            if (&reset_advance) begin
                reset_stage <= reset_stage + 1;
                reset_count <= reset_delay;
                //TODO: Update reset_delay
                reset_advance <= 0;
            end else begin
                if (reset_count != 0) reset_count <= reset_count - 1;
                reset_advance <= {reset_advance[2:0], reset_watch}; //Sync & mini-delay
            end
        end
    end

    reg  rst_user_base;
    always @(posedge user_clk_g) begin
        rst_user_base = reset_lines[0] || (&reset_r); //USER-clock domain (already)
        //Though no need to sync here, nice to pin down signal origin to sync element
    end

    //A mini reset "tree" for more flexible placement on the way to each domain
    //NOTE:Creates a little latency & discrepancies based on each domain period
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE" *)
    reg  [ 7:0] reset_cpu_clkCPU, reset_dvi_clkDVI;
    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF" *)
    reg  [ 7:0] reset_cpu_rr, reset_dvi_rr;
    always @(posedge cpu_clk_g) begin //CPU-clock
        reset_cpu_clkCPU  <= reset_lines;
        reset_cpu_rr      <= reset_cpu_clkCPU;
    end
    always @(posedge dvi_clk_g) begin //DVI-clock
        reset_dvi_clkDVI  <= reset_lines;
        reset_dvi_rr      <= reset_dvi_clkDVI;
    end

    assign rst_cpu_mem_g = reset_cpu_rr[1],
           rst_cpu_bus_g = reset_cpu_rr[2],
           rst_cpu_cpu_g = reset_cpu_rr[3];
    assign rst_dvi_bus_g = reset_dvi_rr[2];


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
        .CLKIN(user_clk_g), .RST(rst_user_base), .LOCKED(pll_lock),
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



`ifndef COLT45_KILLFUN //Just to trigger text editor to hide this section

//Mods, Extras, Crossover from Fall13
  `define SRAM_ENABLE

    Debouncer #(
        .Width(16) // 2^16 / 50MHz => apprx 1.3 ms?
    ) togglestall_debone (
        .Clock(cpu_clk_g),
        .Reset(rst_cpu_bus_g),
        .Enable(1'b1),
        .In(GPIO_DIP[0]),
        .Out(toggle_stall)
    );

//Old dip stall toggle from prior checkpoints
generate if (COLT45_STALLDIP) begin:_STALL_DIP_

    reg man_stall_reg; //TODO: Upgrade to "stall ring" from testbenches
    always@(posedge cpu_clk_g) begin:_MAN_STALL_REG_
        if(rst_cpu_bus_g) begin
            man_stall_reg <= 1'b0;
        end else if (toggle_stall) begin
            man_stall_reg <= ~man_stall_reg;
        end else begin
            man_stall_reg <= 1'b0;
        end
    end

    assign stall_dip = man_stall_reg;

end else begin:_STALL_MEMONLY_
    assign stall_dip = 1'b0;
end endgenerate


//CROSS: SRAM driver from FALL13
  // -- |SRAM Controller| ------------------------------------------------------
  wire sram_clock, sram_ready, sram_addr_valid, sram_data_out_valid;
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
    assign sram_locked = 1'b0;
    assign SRAM_CLK=1'b0, SRAM_CS_B=1'b1, SRAM_WE_B=1'b1, SRAM_MODE=1'b0,
            SRAM_ADV_LD_B=1'b1, SRAM_OE_B=1'b1, SRAM_D={36{1'bz}}, SRAM_A=0,
            SRAM_BW=4'b1111; //TODO:What is width of SRAM_BW with parity???
  `endif // SRAM_ENABLE

`endif // COLT45_KILLFUN

//Master & I/O hookups
  assign stall_top = stall_dip || stall_icache || stall_dcache; //stall_cache
  assign button_reset = GPIO_COMPPB[4]; //GPIO_SW_C (Center Push-button)
  assign GPIO_LED     = {sram_locked, 1'b0, 1'b0, toggle_stall,
                          stall_dip, stall_top, pll_lock, init_done};
  assign GPIO_COMPLED = reset_lines[4:0] ^ GPIO_COMPPB; //Compass LED lights mimic pushbuttons (invert)
  assign BUS_ERROR_1  = sram_locked ^ FPGA_CPU_RESET_B;
  assign BUS_ERROR_2  = pll_lock ^ FPGA_CPU_RESET_B;

endmodule
