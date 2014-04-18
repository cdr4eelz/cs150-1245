//----------------------------------------------------------------------
// Module: CacheTestBench.v
// Authors: Dan Yeager, James Parker, Daiwei Li
// This module directly tests the cache module
// DDR2 / FIFO requests must be "faked"
//
// *** NOTES ***
//----------------------------------------------------------------------

`timescale 1ns / 1ps

module CacheTestBench;
    parameter TB_DEBUG_OUT = 1;
    parameter MAX_STALLS  = 50; // simple time-out
    parameter HEARTBEAT = 1000; // 1 unit = 10ns

    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)

    // Reference Clock (100MHz) & board reset (elimated)
    reg USER_CLK, USER_RST; //TODO:Wrap in a module (also rst_pll, et.al.)
    localparam Cycle = (2 * HalfCycle);
    initial USER_CLK = 0;
    always #(HalfCycle) USER_CLK= ~USER_CLK;

    // PLL driven clocks, locks & reset
    wire user_clk_g, pll_lock, init_done;
    wire cpu_clk_g, dvi_clk_g, clk200_g, clk0_g, clk90_g, clkdiv0_g;
    reg  rst_pll, rst_cpu_mem, rst_cpu_bus, rst_dvi_bus, rst_cpu_cpu;

    // DDR via MIG
    wire [12:0] DDR2_A;
    wire [1:0] DDR2_BA;
    wire DDR2_CAS_B;
    wire DDR2_CKE;
    wire [1:0] DDR2_CLK_N;
    wire [1:0] DDR2_CLK_P;
    wire DDR2_CS_B;
    wire [63:0]  DDR2_D;
    wire [7:0]   DDR2_DM;
    wire [7:0]   DDR2_DQS_N;
    wire [7:0]   DDR2_DQS_P;
    wire DDR2_ODT;
    wire DDR2_RAS_B;
    wire DDR2_WE_B;

    // Memory150
    reg  [31:0] dcache_addr,    icache_addr;
    reg  [ 3:0] dcache_we,      icache_we;
    reg         dcache_re,      icache_re;
    reg  [31:0] dcache_din,     icache_din;
    wire [31:0] dcache_dout,    icache_dout;
    wire        stall;
    reg         video_ready;
    wire        video_valid;
    wire [23:0] video;
    wire        pf_irq;
    wire [31:0] gp_code;
    wire [31:0] gp_frame;
    wire        gp_valid;


    Memory150 #(
        .SIM_ONLY(1'b1)
    ) mem_arch(
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

        .DDR2_A(DDR2_A),
        .DDR2_BA(DDR2_BA),
        .DDR2_CAS_B(DDR2_CAS_B),
        .DDR2_CKE(DDR2_CKE),
        .DDR2_CLK_N(DDR2_CLK_N),
        .DDR2_CLK_P(DDR2_CLK_P),
        .DDR2_CS_B(DDR2_CS_B),
        .DDR2_D(DDR2_D),
        .DDR2_DM(DDR2_DM),
        .DDR2_DQS_N(DDR2_DQS_N),
        .DDR2_DQS_P(DDR2_DQS_P),
        .DDR2_ODT(DDR2_ODT),
        .DDR2_RAS_B(DDR2_RAS_B),
        .DDR2_WE_B(DDR2_WE_B),

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

        .video          (video      ),
        .video_ready    (video_ready),
        .video_valid    (video_valid),
        .pf_irq(pf_irq),
        .gp_code    (gp_code),
        .gp_frame   (gp_frame),
        .gp_valid   (gp_valid)
    );

    mt4htf3264hy ddr2(
        .DDR2_A(DDR2_A),
        .DDR2_BA(DDR2_BA),
        .DDR2_CAS_B(DDR2_CAS_B),
        .DDR2_CKE(DDR2_CKE),
        .DDR2_CLK_N(DDR2_CLK_N),
        .DDR2_CLK_P(DDR2_CLK_P),
        .DDR2_CS_B(DDR2_CS_B),
        .DDR2_D(DDR2_D),
        .DDR2_DM(DDR2_DM),
        .DDR2_DQS_N(DDR2_DQS_N),
        .DDR2_DQS_P(DDR2_DQS_P),
        .DDR2_ODT(DDR2_ODT),
        .DDR2_RAS_B(DDR2_RAS_B),
        .DDR2_WE_B(DDR2_WE_B)
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


    // Test log variables
    integer numFails,     ccDelayCnt;
    integer readNumD,     writeNumD;
    integer readNumI,     writeNumI;
    integer writeNumLine, writeNumPixel;
    integer ccCnt;
    reg [8*21:0] StrRW; // "read" or "write"

    // Modular cache testing procedures
    `include "CacheTestTasks.vh"

initial begin
    $timeformat(-9, 1, " ns", 3);
    // $timeformat [ ( n, p, suffix , min_field_width ) ] ;
    //    units = 1 second ** (-n), n = 0->15, e.g. for n = 9, units = ns
    //    p = digits after decimal point for %t e.g. p = 5 gives 0.00000
    //    suffix for %t (despite timescale directive), ex " ns"
    //    min_field_width is number of character positions for %t */
    //#1;
    // Debugging status variables:
    numFails   = 0;
    readNumD   = 0;
    writeNumD  = 0;
    readNumI   = 0;
    writeNumI  = 0;
    ccDelayCnt = 0;
    // Inputs:
    icache_re  = 0;
    dcache_re  = 0;
    icache_we  = 4'b0;
    dcache_we  = 4'b0;
    dcache_din = 32'b0;
    icache_din = 32'b0;
    dcache_addr= 32'h00000000;
    icache_addr= 32'h00000000;
    video_ready= 0;


    {rst_pll, rst_dvi_bus, rst_cpu_bus, rst_cpu_mem, rst_cpu_cpu} = 5'b11111;
    repeat (2) @( posedge user_clk_g ) ;
    rst_pll = 0;
    wait ( pll_lock ) ; // wait for pll to lock
    repeat (10) @( posedge cpu_clk_g ) ; // reset for 10 cc
    rst_cpu_mem = 0;
    wait ( init_done ) ; // wait for ddr init done
    repeat (2) @( posedge cpu_clk_g ) ;
    @( negedge cpu_clk_g ) ;
    fork
        @( posedge cpu_clk_g ) rst_cpu_bus = 0;
        @( posedge dvi_clk_g ) rst_dvi_bus = 0;
    join
    repeat (2) @( posedge cpu_clk_g ) ;
    {rst_pll, rst_dvi_bus, rst_cpu_bus, rst_cpu_mem, rst_cpu_cpu} = 0;
    repeat (2) @( posedge cpu_clk_g ) ;


    cacheWriteThruTest();
    // cacheAssocFourWay();

    if(numFails == 0) begin
    $display(" All tests PASSED ");
    end else begin
    $display(" ** FAIL ** ");
    $display("%d tests failed.", numFails);
    end

    $finish();
end


    task cacheWriteThruTest;
    begin
        // Try storing a word and reading it, no eviction:
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Then cause the row to be evicted
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);

        // now try to read the original data:
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
    end endtask

    task cacheAssocFourWay;
    begin
        // Store a word into way 1, read it out
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Overwrite it, read it back, then write back the original value
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
        SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Store a word into way 2, read it out, and the word from way 1
        SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

        // Store a word into way 3
        SingleCacheWrite(`DCACHE, 32'h00200000, 32'h12341234, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b1);

        // and read words from ways 1 and 2
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

        // Store a word into way 4
        SingleCacheWrite(`DCACHE, 32'h00300000, 32'h43211234, 4'b1111, 1'b0);

        // and read it out
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b0);
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b1);

        // and read words from ways 1, 2, and 3
        SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00200000, 32'h12341234, 1'b1);
        SingleCacheRead(`DCACHE, 32'h00300000, 32'h43211234, 1'b1);
    end endtask

    // Simulation takes a long time
    // Provide some info that its not hung:
    always @ (posedge cpu_clk_g) begin
        if(ccCnt < HEARTBEAT) begin
            ccCnt = ccCnt + 1;
        end else begin
            ccCnt = 0;
            $display("TB: Time = %t", $time);
        end
    end

endmodule
