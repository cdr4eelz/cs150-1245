
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
    wire [31:0] video;//[23:0]
    wire        pf_vframe,    gp_vcode, gp_vframe;
    wire [31:0] pf_wframe,    gp_wcode, gp_wframe;
    wire [31:0]               gp_rcode;
    wire [15:0] pf_status,              gp_status;
    wire        irq_pf_frame, irq_gp_done;
    Memory150 #(
        .SIM_ONLY(1'b1),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) mem_arch (
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

        .pf_vframe(pf_vframe),        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                      .gp_rcode(gp_rcode),
        .pf_status(pf_status),                             .gp_status(gp_status),
        .irq_pf_frame(irq_pf_frame),  .irq_gp_done(irq_gp_done)
    );
