    localparam real TPROP_DQS          = 0.00;
    localparam real TPROP_DQS_RD       = 0.00;
    localparam real TPROP_PCB_CTRL     = 0.00;
    localparam real TPROP_PCB_DATA     = 0.00;
    localparam real TPROP_PCB_DATA_RD  = 0.00;
    localparam MEMORY_WIDTH            = 16;
    parameter RST_ACT_LOW           = 1;
    parameter CA_MIRROR             = "OFF";
    parameter DQ_WIDTH              = 16;
    parameter DQS_WIDTH             = 2;
    parameter ROW_WIDTH             = 14;
    parameter CS_WIDTH              = 1;
    parameter DM_WIDTH              = 2;
    parameter ODT_WIDTH             = 1;
    parameter ADDR_WIDTH            = 28;
    parameter COL_WIDTH             = 10;
    parameter tCK                   = 3077;
    parameter REFCLK_FREQ           = 200.0;
    parameter nCK_PER_CLK           = 4;
// More details though not all are used:
    parameter DQS_CNT_WIDTH         = 1;
    parameter DRAM_WIDTH            = 8;
    parameter RANKS                 = 1;
    parameter BURST_MODE            = "8";
    parameter SIM_BYPASS_INIT_CAL   = "FAST";
    parameter TCQ                   = 100;
    parameter DEBUG_PORT            = "OFF";
    localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;
    localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
    localparam RESET_PERIOD = 200000; //in pSec
    localparam real SYSCLK_PERIOD = tCK;

    wire sys_rst_n = BOARD_RST_N; //Matches some MIG-device modules from example.
    wire init_done; //Set by MemoryDDR  WAS: DUT.init_calib_complete; // Peek into private signal of the DUT

    // Coming from FPGA (the MIG outputs):
    wire [DQ_WIDTH-1:0]         ddr3_dq_fpga;
    wire [DQS_WIDTH-1:0]        ddr3_dqs_p_fpga;
    wire [DQS_WIDTH-1:0]        ddr3_dqs_n_fpga;
    wire [ROW_WIDTH-1:0]        ddr3_addr_fpga;
    wire [3-1:0]                ddr3_ba_fpga;
    wire                        ddr3_ras_n_fpga;
    wire                        ddr3_cas_n_fpga;
    wire                        ddr3_we_n_fpga;
    wire [1-1:0]                ddr3_cke_fpga;
    wire [1-1:0]                ddr3_ck_p_fpga;
    wire [1-1:0]                ddr3_ck_n_fpga;
    wire [(CS_WIDTH*1)-1:0]     ddr3_cs_n_fpga;
    wire [DM_WIDTH-1:0]         ddr3_dm_fpga;
    wire [ODT_WIDTH-1:0]        ddr3_odt_fpga;
    // Headed toward DDR3 SDRAM Mem model/simulator:
    reg  [(CS_WIDTH*1)-1:0]     ddr3_cs_n_sdram_tmp;
    reg  [DM_WIDTH-1:0]         ddr3_dm_sdram_tmp;
    reg  [ODT_WIDTH-1:0]        ddr3_odt_sdram_tmp;
    wire [DQ_WIDTH-1:0]         ddr3_dq_sdram;
    reg  [ROW_WIDTH-1:0]        ddr3_addr_sdram [0:1];
    reg  [3-1:0]                ddr3_ba_sdram [0:1];
    reg                         ddr3_ras_n_sdram;
    reg                         ddr3_cas_n_sdram;
    reg                         ddr3_we_n_sdram;
    wire [(CS_WIDTH*1)-1:0]     ddr3_cs_n_sdram;
    wire [ODT_WIDTH-1:0]        ddr3_odt_sdram;
    reg  [1-1:0]                ddr3_cke_sdram;
    wire [DM_WIDTH-1:0]         ddr3_dm_sdram;
    wire [DQS_WIDTH-1:0]        ddr3_dqs_p_sdram;
    wire [DQS_WIDTH-1:0]        ddr3_dqs_n_sdram;
    reg  [1-1:0]                ddr3_ck_p_sdram;
    reg  [1-1:0]                ddr3_ck_n_sdram;
    wire    ddr3_reset_n;   // Direct wire between FPGA & SDRAM

    fetcher_top #(
        .SIMULATION(SIMULATION),
        .CLKIN_PERIOD(CLKIN_PERIOD)
    ) DUT (
    // Clocks and GPIO
        .BOARD_CLK_100MHz   (BOARD_CLK_100MHz), // IN
        .BOARD_RST_N        (BOARD_RST_N),      // IN
        .sw(sw), .btn(btn),     // IN  [3:0]    4 switches, 4 pushbuttons
        .led(led),              // OUT [3:0]    4 on/off LEDs, non-RBG LEDs
        .led0_b(led0_b),    .led1_g(led1_g),    //OUT   Assorted colors from...
        .led2_r(led2_r),    .led3_b(led3_b),    //OUT   ...each of 4 RGB LEDs
    // DDR3 InOuts
        .ddr3_dq        (ddr3_dq_fpga),      // INOUT [15:0]
        .ddr3_dqs_p     (ddr3_dqs_p_fpga),   // INOUT  [1:0]
        .ddr3_dqs_n     (ddr3_dqs_n_fpga),   // INOUT  [1:0]
    // DDR3 Outputs
        .ddr3_addr      (ddr3_addr_fpga),    // OUT [13:0]
        .ddr3_ba        (ddr3_ba_fpga),      // OUT  [2:0]
        .ddr3_ras_n     (ddr3_ras_n_fpga),   // OUT
        .ddr3_cas_n     (ddr3_cas_n_fpga),   // OUT
        .ddr3_we_n      (ddr3_we_n_fpga),    // OUT
        .ddr3_ck_p      (ddr3_ck_p_fpga),    // OUT  [0:0]
        .ddr3_ck_n      (ddr3_ck_n_fpga),    // OUT  [0:0]
        .ddr3_cke       (ddr3_cke_fpga),     // OUT  [0:0]
        .ddr3_cs_n      (ddr3_cs_n_fpga),    // OUT  [0:0]
        .ddr3_dm        (ddr3_dm_fpga),      // OUT  [1:0]
        .ddr3_odt       (ddr3_odt_fpga),     // OUT  [0:0]
        .ddr3_reset_n   (ddr3_reset_n)  // OUT
    );

//**************************************************************************//

    always @( * ) begin
        ddr3_ck_p_sdram     <=  #(TPROP_PCB_CTRL)   ddr3_ck_p_fpga;
        ddr3_ck_n_sdram     <=  #(TPROP_PCB_CTRL)   ddr3_ck_n_fpga;
        ddr3_addr_sdram[0]  <=  #(TPROP_PCB_CTRL)   ddr3_addr_fpga;
        ddr3_addr_sdram[1]  <=  #(TPROP_PCB_CTRL)   (CA_MIRROR == "ON") ?
                                                        {ddr3_addr_fpga[ROW_WIDTH-1:9],
                                                            ddr3_addr_fpga[7], ddr3_addr_fpga[8],
                                                            ddr3_addr_fpga[5], ddr3_addr_fpga[6],
                                                            ddr3_addr_fpga[3], ddr3_addr_fpga[4],
                                                            ddr3_addr_fpga[2:0]}
                                                        : ddr3_addr_fpga;
        ddr3_ba_sdram[0]    <=  #(TPROP_PCB_CTRL)   ddr3_ba_fpga;
        ddr3_ba_sdram[1]    <=  #(TPROP_PCB_CTRL)   (CA_MIRROR == "ON") ?
                                                        {ddr3_ba_fpga[3-1:2],
                                                            ddr3_ba_fpga[0],
                                                            ddr3_ba_fpga[1]}
                                                        : ddr3_ba_fpga;
        ddr3_ras_n_sdram    <=  #(TPROP_PCB_CTRL)   ddr3_ras_n_fpga;
        ddr3_cas_n_sdram    <=  #(TPROP_PCB_CTRL)   ddr3_cas_n_fpga;
        ddr3_we_n_sdram     <=  #(TPROP_PCB_CTRL)   ddr3_we_n_fpga;
        ddr3_cke_sdram      <=  #(TPROP_PCB_CTRL)   ddr3_cke_fpga;
    end

    always @( * )
        ddr3_cs_n_sdram_tmp   <=  #(TPROP_PCB_CTRL) ddr3_cs_n_fpga;
    assign ddr3_cs_n_sdram =  ddr3_cs_n_sdram_tmp;

    always @( * )
        ddr3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) ddr3_dm_fpga;//DM signal generation
    assign ddr3_dm_sdram = ddr3_dm_sdram_tmp;

    always @( * )
        ddr3_odt_sdram_tmp  <=  #(TPROP_PCB_CTRL) ddr3_odt_fpga;
    assign ddr3_odt_sdram =  ddr3_odt_sdram_tmp;


    // Controlling the bi-directional BUS
    genvar dqwd;
    generate
        for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay
            WireDelay # (
                .Delay_g    (TPROP_PCB_DATA),
                .Delay_rd   (TPROP_PCB_DATA_RD),
                .ERR_INSERT ("OFF")
            ) u_delay_dq (
                .A             (ddr3_dq_fpga[dqwd]),
                .B             (ddr3_dq_sdram[dqwd]),
                .reset         (sys_rst_n),
                .phy_init_done (init_done)
            );
        end
        WireDelay # (
            .Delay_g    (TPROP_PCB_DATA),
            .Delay_rd   (TPROP_PCB_DATA_RD),
            .ERR_INSERT ("OFF")
        ) u_delay_dq_0 (
            .A             (ddr3_dq_fpga[0]),
            .B             (ddr3_dq_sdram[0]),
            .reset         (sys_rst_n),
            .phy_init_done (init_done)
        );
    endgenerate

    genvar dqswd;
    generate
        for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay
            WireDelay # (
                .Delay_g    (TPROP_DQS),
                .Delay_rd   (TPROP_DQS_RD),
                .ERR_INSERT ("OFF")
            ) u_delay_dqs_p (
                .A             (ddr3_dqs_p_fpga[dqswd]),
                .B             (ddr3_dqs_p_sdram[dqswd]),
                .reset         (sys_rst_n),
                .phy_init_done (init_done)
            );

            WireDelay # (
                .Delay_g    (TPROP_DQS),
                .Delay_rd   (TPROP_DQS_RD),
                .ERR_INSERT ("OFF")
            ) u_delay_dqs_n (
                .A             (ddr3_dqs_n_fpga[dqswd]),
                .B             (ddr3_dqs_n_sdram[dqswd]),
                .reset         (sys_rst_n),
                .phy_init_done (init_done)
            );
        end
    endgenerate

    //**************************************************************************//
    // Memory Models instantiations
    //**************************************************************************//

    genvar r,i;
    generate
        for (r = 0; r < CS_WIDTH; r = r + 1) begin: mem_rnk
            if(DQ_WIDTH/16) begin: mem
                for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
                    ddr3_model u_comp_ddr3
                    (
                        .rst_n   (ddr3_reset_n),
                        .ck      (ddr3_ck_p_sdram),
                        .ck_n    (ddr3_ck_n_sdram),
                        .cke     (ddr3_cke_sdram[r]),
                        .cs_n    (ddr3_cs_n_sdram[r]),
                        .ras_n   (ddr3_ras_n_sdram),
                        .cas_n   (ddr3_cas_n_sdram),
                        .we_n    (ddr3_we_n_sdram),
                        .dm_tdqs (ddr3_dm_sdram[(2*(i+1)-1):(2*i)]),
                        .ba      (ddr3_ba_sdram[r]),
                        .addr    (ddr3_addr_sdram[r]),
                        .dq      (ddr3_dq_sdram[16*(i+1)-1:16*(i)]),
                        .dqs     (ddr3_dqs_p_sdram[(2*(i+1)-1):(2*i)]),
                        .dqs_n   (ddr3_dqs_n_sdram[(2*(i+1)-1):(2*i)]),
                        .tdqs_n  (),
                        .odt     (ddr3_odt_sdram[r])
                    );
                end
            end
            if (DQ_WIDTH%16) begin: gen_mem_extrabits
                ddr3_model u_comp_ddr3
                (
                    .rst_n   (ddr3_reset_n),
                    .ck      (ddr3_ck_p_sdram),
                    .ck_n    (ddr3_ck_n_sdram),
                    .cke     (ddr3_cke_sdram[r]),
                    .cs_n    (ddr3_cs_n_sdram[r]),
                    .ras_n   (ddr3_ras_n_sdram),
                    .cas_n   (ddr3_cas_n_sdram),
                    .we_n    (ddr3_we_n_sdram),
                    .dm_tdqs ({ddr3_dm_sdram[DM_WIDTH-1],ddr3_dm_sdram[DM_WIDTH-1]}),
                    .ba      (ddr3_ba_sdram[r]),
                    .addr    (ddr3_addr_sdram[r]),
                    .dq      ({ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)],
                    ddr3_dq_sdram[DQ_WIDTH-1:(DQ_WIDTH-8)]}),
                    .dqs     ({ddr3_dqs_p_sdram[DQS_WIDTH-1],
                    ddr3_dqs_p_sdram[DQS_WIDTH-1]}),
                    .dqs_n   ({ddr3_dqs_n_sdram[DQS_WIDTH-1],
                    ddr3_dqs_n_sdram[DQS_WIDTH-1]}),
                    .tdqs_n  (),
                    .odt     (ddr3_odt_sdram[r])
                );
            end
        end
    endgenerate


        // MemoryDDR (WAS: Memory150)
        wire [31:0] dcache_addr,    icache_addr;
        wire [ 3:0] dcache_we,      icache_we;
        wire        dcache_re,      icache_re;
        wire [31:0] dcache_din,     icache_din;
        wire [31:0] dcache_dout,    icache_dout;
        wire        stall_dcache,   stall_icache; //stall_cache;
        wire  [3:0] DBG_dcache,     DBG_icache;
        wire        video_ready,    video_valid;
        wire [31:0] video;//[23:0]
    //  wire        fb0; ???Was this "framebuffer0" like pf_wframe???
        wire        pf_vframe,  gp_vcode,   gp_vframe;
        wire [31:0] pf_wframe,  gp_wcode,   gp_wframe;
        wire [31:0]             gp_rcode;
        wire [15:0] pf_status,              gp_status;
        wire        irq_pf_frame,   irq_gp_done;

        MemoryDDR #(
            .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT)
        ) mem_arch (
        // Critical clock & reset
            .clk_cpu        (clk_cpu),
            .clk_pix        (clk_pix),
            .clk_mig_sys    (clk_mig_sys),
            .clk_mig_ref    (clk_mig_ref),
            .rst_cpu_mem    (rst_cpu),
            .rst_cpu_bus    (rst_cpu),  //TODO: Distinguish "mem" & "bus" & CPU resets?
            .rst_pix        (rst_pix),
            .locked         (locked_top_clocks),  //Acts as an active HIGH reset
            .init_done      (init_done),  // Output HIGH when MIG is ready

        // DDR3 InOuts
            .ddr3_dq        (ddr3_dq),      // inout  [15:0]
            .ddr3_dqs_n     (ddr3_dqs_n),   // inout  [1:0]
            .ddr3_dqs_p     (ddr3_dqs_p),   // inout  [1:0]
        // DDR3 Outputs
            .ddr3_addr      (ddr3_addr),    // output [13:0]
            .ddr3_ba        (ddr3_ba),      // output [2:0]
            .ddr3_ras_n     (ddr3_ras_n),   // output
            .ddr3_cas_n     (ddr3_cas_n),   // output
            .ddr3_we_n      (ddr3_we_n),    // output
            .ddr3_ck_p      (ddr3_ck_p),    // output [0:0]
            .ddr3_ck_n      (ddr3_ck_n),    // output [0:0]
            .ddr3_cke       (ddr3_cke),     // output [0:0]
            .ddr3_cs_n      (ddr3_cs_n),    // output [0:0]
            .ddr3_dm        (ddr3_dm),      // output [1:0]
            .ddr3_odt       (ddr3_odt),     // output [0:0]
            .ddr3_reset_n   (ddr3_reset_n), // output //How to utilize this???

        // Cache <=> CPU interface:
            .dcache_addr(dcache_addr),  .icache_addr(icache_addr),  //input[31:0]
            .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),  //input[3:0]
            .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),  //input
            .dcache_din (dcache_din ),  .icache_din (icache_din ),  //input[31:0]
            .dcache_dout(dcache_dout),  .icache_dout(icache_dout),  //output[31:0]
            .d_stall   (stall_dcache),  .i_stall   (stall_icache),  //output
            .DBG_dcache (DBG_dcache ),  .DBG_icache (DBG_icache ),  //output[3:0]

        // PixelFeeder <=> DVI driver:
            .video_ready(video_ready),  //input
            .video_valid(video_valid),  //output
            .video      (video      ),  //output[31:0] ([23:0] high byte not used)

        // GPU <=> CPU interface:
            .pf_vframe  (pf_vframe),    .gp_vcode(gp_vcode),    .gp_vframe(gp_vframe),  //input
            .pf_wframe  (pf_wframe),    .gp_wcode(gp_wcode),    .gp_wframe(gp_wframe),  //input [31:0]
                                        .gp_rcode(gp_rcode),                            //output[31:0]
            .pf_status  (pf_status),                            .gp_status(gp_status),  //output[15:0]
            .irq_pf_frame(irq_pf_frame), .irq_gp_done(irq_gp_done)                      //output
        );


/* OLD MEMORY RELATED SIGNALS...
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
*/
