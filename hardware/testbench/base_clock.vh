
    // Reference Clock (100MHz) & board reset

    reg BOARD_CLK_100MHz; // Board clock for Arty-A7
    //reg CLK_125MHz;  // Board clock for PYNQ
    reg BOARD_RST_N;      // "ChipKit Reset" (Active LOW)

    initial BOARD_CLK_100MHz = 0;
    always #(HalfCycle) BOARD_CLK_100MHz = ~BOARD_CLK_100MHz;

    //wire reset_top_clocks = !BOARD_RST_N;
    wire reset_top_clocks;
    ButtonClean #( .Width(1) ) clean_rst_top (
        .Inputs(!BOARD_RST_N),
        .Clock(BOARD_CLK_100MHz), .Reset(1'b0),
        .Outputs(reset_top_clocks)
    );  //assign reset_top_clocks = !BOARD_RST_N;  // Top CLocks are first to come out of reset

    wire locked_top_clocks;  // Participate in startup sequence
    wire clk_mig_sys, clk_mig_ref, clk_cpu, clk_pix;
    clk_wiz_0 top_clocks (  // Generate various clocks for components
    // Clock in ports
        .clk_in_100MHz(BOARD_CLK_100MHz), //WAS: clk_in_100MHz_g),  // INPUT for Arty-A7 or PYNQ CPU
        //.clk_in_125MHz(CLK_125MHz),  // INPUT for PYNQ (from board)
    // Clock out ports (rebuild clk_wiz if needs change)
        .clk_mig_100MHz     (clk_mig_sys),  // output MIG primary clk
        .clk_migref_200MHz  (clk_mig_ref),  // output REF clk for MIG
        .clk_pixel_40MHz    (clk_pix),      // output Pixel for VGA/DVI
        .clk_cpu_50MHz      (clk_cpu),      // output modest CPU speed
        // Status and control signals
        .reset(reset_top_clocks),  // input reset (ACTIVE HIGH)
        .locked(locked_top_clocks)  // output locked (ACTIVE HIGH)
    );  // NOTE: clk_wiz puts BUFG on its output clocks

    // Then some other support components come out of reset (like DRAM)
    wire rst_cpu, rst_pix, init_done;  // TODO: CPU comes out of reset after everything else
    Synchronizer #( .Width(1) ) sync_rst_cpu (
        .async_signal(!locked_top_clocks || !init_done ),
        .Clock(clk_cpu),  .sync_signal(rst_cpu));  // NOTE: This clock is bad when PLL not locked!
    Synchronizer #( .Width(1) ) sync_rst_pix (
        .async_signal(!locked_top_clocks || !init_done),
        .Clock(clk_pix),  .sync_signal(rst_pix));  // NOTE: This clock is bad when PLL not locked!


task BaseClockReset;
begin
    $display("Resetting clocks...");
    BOARD_RST_N = 0; //Active-LOW
    repeat (3) @( posedge BOARD_CLK_100MHz ) ;
    BOARD_RST_N = 1;
    wait ( locked_top_clocks ) ; // wait for pll to lock
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
    repeat (2) @( posedge cpu_clk_g ) ;
    $display("Resetting clocks... done.");
end
endtask


/*  reg USER_CLK, USER_RST;
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
*/
