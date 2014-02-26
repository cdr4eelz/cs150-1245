`timescale 1ns/1ps

`include "cpuglobal.vh"

module CPUEchoDDRTestbench;
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
    wire [31:0] dcache_addr,    icache_addr;
    wire [ 3:0] dcache_we,      icache_we;
    wire        dcache_re,      icache_re;
    wire [31:0] dcache_din,     icache_din;
    wire [31:0] dcache_dout,    icache_dout;
    wire        stall;
    wire        video_ready;
    wire        video_valid;
    wire [23:0] video;
    wire        frame_interrupt;
    wire [31:0] gp_code;
    wire [31:0] gp_frame;
    wire        gp_valid;

    // UART (serial)
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;
    reg   [7:0] DataIn;
    reg         DataInValid;
    wire        DataInReady;
    wire  [7:0] DataOut;
    wire        DataOutValid;
    reg         DataOutReady;


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
        .phy_init_done(init_done),
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
        .frame_interrupt(frame_interrupt),
        .cpu_gp_code    (gp_code),
        .cpu_gp_frame   (gp_frame),
        .cpu_gp_valid   (gp_valid)
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

    UART #(
        .ClockFreq(CPU_FREQ)
    ) uart (
        .Clock  (cpu_clk_g  ),
        .Reset  (rst_cpu_cpu),
        .DataIn      (DataIn      ),
        .DataInValid (DataInValid ),
        .DataInReady (DataInReady ),
        .DataOut     (DataOut     ),
        .DataOutValid(DataOutValid),
        .DataOutReady(DataOutReady),
        .SIn    (FPGA_SERIAL_TX),
        .SOut   (FPGA_SERIAL_RX)
    );

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    CPUEchoDDR DUT(
        .clk    (cpu_clk_g  ),
        .rst    (rst_cpu_cpu),
        .FPGA_SERIAL_RX (FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX (FPGA_SERIAL_TX),
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
        .frame_interrupt(frame_interrupt),
        .gp_code        (gp_code        ),
        .gp_frame       (gp_frame       ),
        .gp_valid       (gp_valid       )
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


initial begin
    DataIn = 8'h7a;
    DataInValid = 0;
    DataOutReady = 0;


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
    repeat (30) @( posedge cpu_clk_g ) ;


    repeat (5) @( posedge cpu_clk_g ) ;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h80;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h81;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);
    // Add more test cases!

    DataIn = 8'h82;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h83;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h84;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h85;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h86;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    DataIn = 8'h87;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);
    $finish();
end

endmodule
