
    // Reference Clock (100MHz) & board reset (elimated)
    reg USER_CLK, USER_RST;
    localparam Cycle = (2 * HalfCycle);
    initial USER_CLK = 0;
    always #(HalfCycle) USER_CLK= ~USER_CLK;

    // PLL driven clocks, locks & reset
    wire user_clk_g, pll_lock, init_done;
    wire cpu_clk_g, dvi_clk_g, clk0_g, clk90_g, clkdiv0_g, clk200_g;
    reg  rst_pll, rst_cpu_mem, rst_cpu_bus, rst_dvi_bus, rst_cpu_cpu;

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

task BaseClockReset;
begin
    $display("Resetting clocks...");
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
    $display("Resetting clocks... done.");
end
endtask
