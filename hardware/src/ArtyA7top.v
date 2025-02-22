module ArtyA7top #(
    parameter CPU_FREQ  = 50_000_000, // LATER (used primarily for BAUD rate calc)
    parameter BAUD_RATE =    115_200,
    CPU_CORE = "" //"DUMPUART"
)(
    input CLK_100MHz,  // Board clock for Arty-A7
    //input CLK_125MHz,  // Board clock for PYNQ
    input CK_RST,  // "ChipKit Reset" (Active LOW)
    // TODO: Debounce CK_RST and feed a simple reset module from it

    // Basic GPIO (Note that some IOs are ignored if not present on other board)
    input   [1:0]   SWITCH,  // Only 2 of 4 switches, PYNQ has only 2
    input   [3:0]   BUTTON,  // 4 pushbuttons
    output  [3:0]   LED,     // 4 on/off LEDs, not RBG LEDs

    // SERIAL (UART)
    input           FPGA_SERIAL_RX,
    output          FPGA_SERIAL_TX,

    // VGA style video Out, 444 RGB (Could dumb down to 4-bits elsewhere)
    output          VGA_HS_O,      // PMOD VGA: H_SYNC
    output          VGA_VS_O,      // PMOD VGA: V_SYNC
    output [3:0]    VGA_R,   // PMOD VGA: 4-bit red
    output [3:0]    VGA_G,   // PMOD VGA: 4-bit green
    output [3:0]    VGA_B    // PMOD VGA: 4-bit blue

/*      // DDR3 via MIG (UPDATE to match constraints file)
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
*/
);

    // BUFFER the board clock (manually switch between Arty-A7 vs PYNQ)
    wire clk_in_100MHz_g, clk_temp_1;  // Arty-A7 or PYNQ ARM-CPU clk-out
    IBUF board_clk_ibuf (.I(CLK_100MHz), .O(clk_temp_1));  // Vivado refuses IBUFG!
    BUFG board_clk_bufg (.I(clk_temp_1), .O(clk_in_100MHz_g));  // Must explicitly add BUFG.
    //wire clk_in_125MHz_G;  // PYNQ board clockDDR
    //IBUFG (.I(CLK_125MHz), .O(clk_in_125MHz_g));

    wire reset_top_clocks, locked_top_clocks;  // Participate in startup sequence
    wire clk_mig, clk_mig_ref, clk_cpu, clk_pix;
    clk_wiz_0 top_clocks (  // Generate various clocks for components
        // Clock in ports
        .clk_in_100MHz(clk_in_100MHz_g),  // INPUT for Arty-A7 or PYNQ CPU
        // .clk_in_125MHz(clk_in_125MHz_g),  // INPUT for PYNQ (from board)
        // Clock out ports (rebuild clk_wiz if needs change)
        .clk_mig_100MHz(clk_mig),               // output MIG primary clk
        .clk_migref_200MHz(clk_mig_ref),        // output REF clk for MIG
        .clk_pixel_40MHz(clk_pix),              // output Pixel for VGA/DVI
        .clk_cpu_50MHz(clk_cpu),                // output modest CPU speed
        // Status and control signals
        .reset(reset_top_clocks),  // input reset (ACTIVE HIGH)
        .locked(locked_top_clocks)  // output locked (ACTIVE HIGH)
    );  // NOTE: clk_wiz puts BUFG on its output clocks

    //TODO: Create a decent "reset tree" to resume components in a good sequence
    //NOTE: Early reset logic must use board-clock "clk_in_100MHz_g"
    ButtonClean #( .Width(1) ) clean_rst_top (
        .Inputs(!CK_RST),
        .Clock(clk_in_100MHz_g), .Reset(1'b0),
        .Outputs(reset_top_clocks)
    );  //assign reset_top_clocks = !CK_RST;  // Top CLocks are first to come out of reset
    // Then some other support components come out of reset (like DRAM)
    wire rst_cpu, rst_pix, init_done;  // CPU comes out of reset after everything else
    Synchronizer #( .Width(1) ) sync_rst_cpu (
        .async_signal(!locked_top_clocks),
        .Clock(clk_cpu),  .sync_signal(rst_cpu));  // NOTE: This clock is bad when PLL not locked!
    Synchronizer #( .Width(1) ) sync_rst_pix (
        .async_signal(!locked_top_clocks),
        .Clock(clk_pix),  .sync_signal(rst_pix));  // NOTE: This clock is bad when PLL not locked!
    

    // Debounce all switch & button signals
    wire [5:0] clean_combo;
    wire [1:0] switches;
    wire [3:0] buttons;
    ButtonClean #( .Width(6) ) clean_GPIO (  // 4 buttons + 2 switches = 6 signals
        .Inputs( { BUTTON[3:0], SWITCH[1:0] } ),  // Merge into 6-bit signal
        .Clock(clk_cpu), .Reset(rst_cpu),
        .Outputs(clean_combo) );
    assign { buttons[3:0], switches[1:0] } = clean_combo;  // Separate the signals

    assign LED[0] = locked_top_clocks ^ buttons[0];
    assign LED[1] = init_done ^ buttons[1]; //CK_RST ^ buttons[1];
    assign LED[2] = reset_top_clocks ^ buttons[2]; //switches[0] && switches[1] && buttons[2];
    assign LED[3] = rst_cpu ^ buttons[3]; //switches[0] && switches[1] && buttons[3];
    // TODO: Map RGB LEDs in constraints file and drive them with PWM

    // Borrowed from 2024/2019 top level IOBs to drive/sense UART serial lines...
    wire cpu_tx, cpu_rx;
    (* IOB = "true" *) reg fpga_serial_tx_iob;
    (* IOB = "true" *) reg fpga_serial_rx_iob;
    assign FPGA_SERIAL_TX = fpga_serial_tx_iob;
    assign cpu_rx = fpga_serial_rx_iob;
    always @(posedge clk_cpu) begin
        fpga_serial_tx_iob <= cpu_tx;
        fpga_serial_rx_iob <= FPGA_SERIAL_RX;
    end

    generate if (CPU_CORE=="ECHOUART") begin:ECHOUART

        CPUEchoUART #( .CPU_FREQ(CPU_FREQ),  .BAUD_RATE(BAUD_RATE)
        ) CPU ( .clk(clk_cpu),  .rst(rst_cpu),  .stall(1'b0),
            .SerialRX(cpu_rx),  .SerialTX(cpu_tx) );
        assign init_done = 1'b1;

    end else if (CPU_CORE=="DUMPUART") begin:DUMPUART
        
        CPUDumpUART #( .CPU_FREQ(CPU_FREQ),  .BAUD_RATE(BAUD_RATE)
        ) CPU ( .clk(clk_cpu),  .rst(rst_cpu),  .stall(1'b0),
            .SerialRX(cpu_rx),  .SerialTX(cpu_tx) );
        assign init_done = 1'b1;

    end else begin:MIPS150

        wire stall_top, stall_dip;
        assign stall_dip = 1'b0;

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

        MemoryDDR #(
            .SIM_ONLY(1'b0)
        ) mem_arch (
            .clk_cpu    (clk_cpu),
            .clk_pix    (clk_pix),
            .clk_mig    (clk_mig),
            .clk_mig_ref(clk_mig_ref),
            .rst_cpu_mem(rst_cpu),  //TODO: Distinguish "mem" & "bus" resets?
            .rst_cpu_bus(rst_cpu),
            .rst_pix    (rst_pix),
            .locked     (locked_top_clocks),
            .init_done  (init_done),  // Output when MIG is ready
        // DDR3 pads:
// .........
        // Cache <=> CPU interface:
            .dcache_addr(dcache_addr), .icache_addr(icache_addr),
            .dcache_we  (dcache_we  ), .icache_we  (icache_we  ),
            .dcache_re  (dcache_re  ), .icache_re  (icache_re  ),
            .dcache_din (dcache_din ), .icache_din (icache_din ),
            .dcache_dout(dcache_dout), .icache_dout(icache_dout),
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

        assign video_ready = 1'b0;
/*
        Memory150 #(
            .SIM_ONLY(1'b0)
        ) mem_arch (
        // Clocks & Resets:
            .cpu_clk_g  (clk_cpu),
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
            .stall(),  //.stall(stall_cache),
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
*/

        // MIPS 150 CPU
        MIPS150 #(
            .CPU_FREQ(CPU_FREQ),
            .BAUD_RATE(BAUD_RATE),
            .PC_BOOT(32'h4000_0000),
            .CPU_CORE("MIPS")
        ) CPU (
            .clk(clk_cpu),  .rst(rst_cpu),  .stall(stall_top),
        // Serial (UART):
            .SerialRX(cpu_rx),  .SerialTX(cpu_tx),
        // Memory Caches:
            .dcache_addr(dcache_addr),    .icache_addr(icache_addr),
            .dcache_we  (dcache_we  ),    .icache_we  (icache_we  ),
            .dcache_re  (dcache_re  ),    .icache_re  (icache_re  ),
            .dcache_din (dcache_din ),    .icache_din (icache_din ),
            .dcache_dout(dcache_dout),    .icache_dout(icache_dout),
        // GPU:
            .pf_vframe(pf_vframe),        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
            .pf_wframe(pf_wframe),        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                            .gp_rcode(gp_rcode),
            .pf_status(pf_status),                             .gp_status(gp_status),
            .irq_pf_frame(irq_pf_frame),  .irq_gp_done(irq_gp_done)
        );

        assign stall_top = stall_dip || stall_icache || stall_dcache; //stall_cache

    end endgenerate

    //assign {VGA_HS_O,VGA_VS_O,VGA_R,VGA_G,VGA_B} = 14'd0; // No video yet
    VGATestPattern vga_gen (
        .PXL_CLK(clk_pix),
        .VGA_HS_O(VGA_HS_O),  .VGA_VS_O(VGA_VS_O),
        .VGA_R(VGA_R),  .VGA_G(VGA_G),  .VGA_B(VGA_B)
    );

endmodule
