module minitop
(
    input        FPGA_SERIAL_RX,
    output       FPGA_SERIAL_TX,
    input        USER_CLK,
    input        USER_RST // Extra connection added to passthrough to embedded stuff
);

    // Global clock lines (use the _g since are buffered)
    wire pll_lock, user_clk_g, cpu_clk_g; //For the MIPSY
    wire clk200_g, clk0_g, clk90_g, clkdiv0_g, clk50_g;


    // Global PLOP lines
    wire PLOP_RST_AUX, PLOP_RST_Periph;
    wire MB0_IRQ0, MB0_IRQ1, MB0_Error, MB0_Halted;
    wire BIOS_BRAM_Clk, BIOS_BRAM_En;
    wire [0:3]  BIOS_BRAM_Wen;
    wire [0:31] BIOS_BRAM_Addr;
    wire [0:31] BIOS_BRAM_Dout, BIOS_BRAM_DIN;
    wire BRK_BRAM_RST, BRK_BRAM_CLK, BRK_BRAM_EN;
    wire [0: 3] BRK_BRAM_WEN;
    wire [0:31] BRK_BRAM_ADDR;
    wire [0:31] BRK_BRAM_DOUT, BRK_BRAM_Din;
    wire BRK_DCR_Rst, BRK_DCR_Clk, BRK_DCR_Read, BRK_DCR_Write, BRK_DCR_ACK;
    wire [0: 9] BRK_DCR_ABus;
    wire [0:31] BRK_DCR_DWBus, BRK_DCR_DRBUS;
    wire [31:0] GPI1_32, GPI2_32, GPI3_32, GPI4_32;
    wire [31:0] GPo1_32, GPo2_32, GPo3_32, GPo4_32;
    wire UART_PHY_RX, UART_PHY_Tx, UART_MIPSY_RX, UART_MIPSY_Tx;



    // PLOP patchwork
    assign PLOP_RST_AUX = 1'b0,
            MB0_IRQ0 = 1'b0,
            MB0_IRQ1 = 1'b0; // PLOP_RST_Periph, MB0_Error, MB0_Halted
    assign BIOS_BRAM_DIN = 32'd0; // ,,,
    assign BRK_BRAM_RST = ~USER_RST, //TODO: Becomes our internal reset/init_done
            BRK_BRAM_CLK = cpu_clk_g, //TODO: Consider faster clock just for BRK
            BRK_BRAM_EN = 1'b0,
            BRK_BRAM_WEN = 4'b0000,
            BRK_BRAM_ADDR = 32'h00000000,
            BRK_BRAM_DOUT = 32'd0; // BRK_BRAM_Din
    assign BRK_DCR_DRBUS = 32'd0; // ,,,
    assign GPI1_32 = 32'd0, GPI2_32 = 32'd0, GPI3_32 = 32'd0, GPI4_32 = 32'd0; // GPo<n>_32
    assign FPGA_SERIAL_TX = UART_PHY_Tx,
            UART_PHY_RX = FPGA_SERIAL_RX,
            UART_MIPSY_RX = 1'b1; // UART_MIPSY_Tx


//Mimic XPS stub instantion name so bmm files match conveniently!
//    (* xBOX_TYPE = "user_black_box" *)
    plop505top
    plop505top_i (
        .CLK_REF_100MHz ( user_clk_g ), //IN CLK 10ns
        .CLK_MIPSY_50MHz( cpu_clk_g ), //IN CLK 20ns
        .RST_PHY_HI     ( ~USER_RST ), //IN RST-HI
        .RST_AUX_HI     ( PLOP_RST_AUX ), //IN RST-HIGH
        .RST_Periph_HI  ( PLOP_RST_Periph ), //OUT RST-HIGH

        // PLOP microblaze_0 state
        .MB0_IRQ0       ( MB0_IRQ0 ), //IN
        .MB0_IRQ1       ( MB0_IRQ1 ), //IN
        .MB0_Error      ( MB0_Error ), //OUT
        .MB0_Halted     ( MB0_Halted ), //OUT

        // Give PLOP back-door access to our BIOS ROM (BRAM)
        .BIOS_BRAM_Clk  ( BIOS_BRAM_Clk ), //OUT
        .BIOS_BRAM_En   ( BIOS_BRAM_En ), //OUT
        .BIOS_BRAM_Wen  ( BIOS_BRAM_Wen ), //output [0:3]
        .BIOS_BRAM_Addr ( BIOS_BRAM_Addr ), //output [0:31]
        .BIOS_BRAM_DIN  ( BIOS_BRAM_DIN ), //input [0:31]
        .BIOS_BRAM_Dout ( BIOS_BRAM_Dout ), //output [0:31]

        // Memory-Map BRK registers, traces, etc.
        .BRK_BRAM_RST   ( BRK_BRAM_RST ), //IN
        .BRK_BRAM_CLK   ( BRK_BRAM_CLK ), //IN
        .BRK_BRAM_EN    ( BRK_BRAM_EN ), //IN
        .BRK_BRAM_WEN   ( BRK_BRAM_WEN ), //input [0:3]
        .BRK_BRAM_ADDR  ( BRK_BRAM_ADDR ), //input [0:31]
        .BRK_BRAM_Din   ( BRK_BRAM_Din ), //output [0:31]
        .BRK_BRAM_DOUT  ( BRK_BRAM_DOUT ), //input [0:31]

        // Expose BRK registers via BRK_DCR
        .BRK_DCR_ACK    ( BRK_DCR_ACK ), //OUT
        .BRK_DCR_DRBUS  ( BRK_DCR_DRBUS ), //input [0:31]
        .BRK_DCR_Read   ( BRK_DCR_Read ), //OUT
        .BRK_DCR_Write  ( BRK_DCR_Write ), //OUT
        .BRK_DCR_ABus   ( BRK_DCR_ABus ), //output [0:9]
        .BRK_DCR_DWBus  ( BRK_DCR_DWBus ), //output [0:31]
        .BRK_DCR_Clk    ( BRK_DCR_Clk ), //OUT
        .BRK_DCR_Rst    ( BRK_DCR_Rst ), //OUT

         //GPIO: input/output [31:0]
        .GPI1_32(GPI1_32), .GPI2_32(GPI2_32), .GPI3_32(GPI3_32), .GPI4_32(GPI4_32),
        .GPo1_32(GPo1_32), .GPo2_32(GPo2_32), .GPo3_32(GPo3_32), .GPo4_32(GPo4_32),

        // UARTs
        .UART_PHY_RX    ( UART_PHY_RX ), //IN
        .UART_PHY_Tx    ( UART_PHY_Tx ), //OUT
        .UART_MIPSY_RX  ( UART_MIPSY_RX ), //IN
        .UART_MIPSY_Tx  ( UART_MIPSY_Tx ) //OUT
    ) /* synthesis syn_noprune=1 */;


    // Raw clock lines (unbuffered, don't use elsewhere)
    wire pll_fb, cpu_clk, clk200, clk0, clk90, clkdiv0, clk50;
    PLL_BASE
    #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN_PERIOD(10.0),    // 100 MHz
        .DIVCLK_DIVIDE(4),      //  / 4
        .CLKFBOUT_MULT(24),     //  * 24
        .CLKFBOUT_PHASE(0.0),
        // --=> 100/4*24 = 600 MHz internal reference

        //cpu_clk: 600 / 12 = 50 MHz
        .CLKOUT0_DIVIDE(12),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),

        //clk200: 600 / 3 => 200 MHz
        .CLKOUT1_DIVIDE(3),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(0.0),

        //clk0: 600 / 3 => 200 MHz 50/50 @0 deg
        .CLKOUT2_DIVIDE(3),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT2_PHASE(0.0),

        //clk90: 600 / 3 => 200 MHz 50/50 @90 deg
        .CLKOUT3_DIVIDE(3),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT3_PHASE(90.0),

        //clkdiv0: 600 / 6 => 100 MHz 50/50 @0 deg
        .CLKOUT4_DIVIDE(6),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT4_PHASE(0.0),

        //clk50: 600 / 12 => 50 MHz 50/50 @0 deg
        .CLKOUT5_DIVIDE(12),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT5_PHASE(0.0),

        .COMPENSATION("SYSTEM_SYNCHRONOUS"),
        .REF_JITTER(0.100)
    )
    user_clk_pll
    (
        .CLKFBOUT(pll_fb),
        .CLKOUT0(cpu_clk),
        .CLKOUT1(clk200),
        .CLKOUT2(clk0),
        .CLKOUT3(clk90),
        .CLKOUT4(clkdiv0),
        .CLKOUT5(clk50),
        .LOCKED(pll_lock),
        .CLKFBIN(pll_fb),
        .CLKIN(user_clk_g),
        .RST(1'b0) //USER_RST seems flawed???
    );

    // Buffer reset/clocks for general use
    IBUFG user_clk_buf ( .I(USER_CLK), .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
    BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
    BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
    BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );
    BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
    BUFG  clkdiv50_buf ( .I(clk50),    .O(clk50_g)    );

endmodule
