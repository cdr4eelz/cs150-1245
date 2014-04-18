//TODO:Wrap almost all of this up in a tb module/task

    // Reference Clock (100MHz) & board reset (elimated)
    reg USER_CLK, USER_RST;
    localparam Cycle = (2 * HalfCycle);
    initial USER_CLK = 0;
    always #(HalfCycle) USER_CLK= ~USER_CLK;

    // PLL driven clocks, locks & reset
    wire user_clk_g, pll_lock, init_done;
    wire cpu_clk_g, dvi_clk_g, clk0_g, clk90_g, clkdiv0_g, clk200_g;
    reg  rst_pll, rst_cpu_mem, rst_cpu_bus, rst_dvi_bus, rst_cpu_cpu;

    // DDR via MIG
    wire [12:0] DDR2_A;
    wire [ 1:0] DDR2_BA;
    wire        DDR2_CAS_B;
    wire        DDR2_CKE;
    wire [ 1:0] DDR2_CLK_N;
    wire [ 1:0] DDR2_CLK_P;
    wire        DDR2_CS_B;
    wire [63:0] DDR2_D;
    wire [ 7:0] DDR2_DM;
    wire [ 7:0] DDR2_DQS_N;
    wire [ 7:0] DDR2_DQS_P;
    wire        DDR2_ODT;
    wire        DDR2_RAS_B;
    wire        DDR2_WE_B;
    mt4htf3264hy ddr2(
        .DDR2_A     (DDR2_A),
        .DDR2_BA    (DDR2_BA),
        .DDR2_CAS_B (DDR2_CAS_B),
        .DDR2_CKE   (DDR2_CKE),
        .DDR2_CLK_N (DDR2_CLK_N),
        .DDR2_CLK_P (DDR2_CLK_P),
        .DDR2_CS_B  (DDR2_CS_B),
        .DDR2_D     (DDR2_D),
        .DDR2_DM    (DDR2_DM),
        .DDR2_DQS_N (DDR2_DQS_N),
        .DDR2_DQS_P (DDR2_DQS_P),
        .DDR2_ODT   (DDR2_ODT),
        .DDR2_RAS_B (DDR2_RAS_B),
        .DDR2_WE_B  (DDR2_WE_B)
    );

    // Memory150
    wire [31:0] dcache_addr,    icache_addr;
    wire [ 3:0] dcache_we,      icache_we;
    wire        dcache_re,      icache_re;
    wire [31:0] dcache_din,     icache_din;
    wire [31:0] dcache_dout,    icache_dout;
    wire        d_stall, i_stall, stall;
    wire        video_ready, video_valid;
    wire [23:0] video;
    wire [15:0] pf_status,  gp_status;
    wire        pf_valid,   gp_valid;
    wire [31:0] pf_frame,   gp_frame,gp_code;
    wire        pf_irq,     gp_irq;
    Memory150 #(
        .SIM_ONLY(1'b1),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) mem_arch(
        .cpu_clk_g(cpu_clk_g),
        .dvi_clk_g(dvi_clk_g),
        .clk0_g   (clk0_g),
        .clkdiv0_g(clkdiv0_g),
        .clk90_g  (clk90_g),
        .clk200_g (clk200_g),
        .locked   (pll_lock),
        .rst_cpu_mem(rst_cpu_mem),
        .init_done  (init_done),
        .rst_cpu_bus(rst_cpu_bus),
        .rst_dvi_bus(rst_dvi_bus),

        .DDR2_A     (DDR2_A),
        .DDR2_BA    (DDR2_BA),
        .DDR2_CAS_B (DDR2_CAS_B),
        .DDR2_CKE   (DDR2_CKE),
        .DDR2_CLK_N (DDR2_CLK_N),
        .DDR2_CLK_P (DDR2_CLK_P),
        .DDR2_CS_B  (DDR2_CS_B),
        .DDR2_D     (DDR2_D),
        .DDR2_DM    (DDR2_DM),
        .DDR2_DQS_N (DDR2_DQS_N),
        .DDR2_DQS_P (DDR2_DQS_P),
        .DDR2_ODT   (DDR2_ODT),
        .DDR2_RAS_B (DDR2_RAS_B),
        .DDR2_WE_B  (DDR2_WE_B),

        .dcache_addr(dcache_addr),  .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),  .icache_din (icache_din ),
        .dcache_dout(dcache_dout),  .icache_dout(icache_dout),
        .stall(stall), .d_stall(d_stall), .i_stall(i_stall),

        .video_ready    (video_ready),
        .video_valid    (video_valid),
        .video          (video      ),

        .pf_status(pf_status),  .gp_status(gp_status),
        .pf_valid(pf_valid),    .gp_valid(gp_valid),
        .pf_frame(pf_frame),    .gp_frame(gp_frame),.gp_code(gp_code),
        .pf_irq(pf_irq),        .gp_irq(gp_irq)
    );

    // UART (serial)
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;
    reg   [7:0] DataIn;
    reg         DataInValid;
    wire        DataInReady;
    wire  [7:0] DataOut;
    wire        DataOutValid;
    reg         DataOutReady;
    UART #( .ClockFreq(CPU_FREQ) ) uart
    ( .Clock(cpu_clk_g), .Reset(rst_cpu_cpu),
        .SIn(FPGA_SERIAL_TX), .DataOut(DataOut),
        .DataOutReady(DataOutReady), .DataOutValid(DataOutValid),
        .DataInReady (DataInReady ), .DataInValid (DataInValid ),
        .DataIn(DataIn), .SOut(FPGA_SERIAL_RX)
    );

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    MemMIPS150 #(
        .CPU_FREQ(CPU_FREQ)
    ) DUT (
        .clk(cpu_clk_g), .rst(rst_cpu_cpu), .stall(stall),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX), .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
        .dcache_addr(dcache_addr),  .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),  .icache_din (icache_din ),
        .dcache_dout(dcache_dout),  .icache_dout(icache_dout),
        .pf_status(pf_status),  .gp_status(gp_status),
        .pf_valid(pf_valid),    .gp_valid(gp_valid),
        .pf_frame(pf_frame),    .gp_frame(gp_frame),.gp_code(gp_code),
        .pf_irq(pf_irq),        .gp_irq(gp_irq)
    );

    //Top clock generator
    wire cpu_clk, dvi_clk, clk200, clk0, clk90, clkdiv0, pll_fb;
    PLL_BASE #(
        .CLKIN_PERIOD(HalfCycle*2), .CLKFBOUT_PHASE(0.0),
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
        .CLKIN(user_clk_g), .RST(rst_pll), .LOCKED(pll_lock),
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
