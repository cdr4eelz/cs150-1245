/*  This top module is based on the old CS150, blended with some modern EECS151,
    plus some oddball customizations I did in the old days.
*/

module ArtyA7top #(
    parameter   CPU_FREQ        =50_000_000, // LATER (used primarily for BAUD rate calc)
                BAUD_RATE       =   115_200,
    parameter   SCREEN_WIDTH    = 800,
                SCREEN_HEIGHT   =     600,
    parameter   CPU_CORE        = "" //"DUMPUART"
)(
    input CLK_100MHz,  // Board clock for Arty-A7
    //input CLK_125MHz,  // Board clock for PYNQ
    input CK_RST_N,  // "ChipKit Reset" (Active LOW)

    // Basic GPIO (Note that some IOs are ignored if not present on other board)
    input   [1:0]   SWITCH,  // Only 2 of 4 switches, PYNQ has only 2
    input   [3:0]   BUTTON,  // 4 pushbuttons
    output  [3:0]   LED,     // 4 on/off LEDs, not RBG LEDs
    output led0_b,  led1_g, led2_r, led3_b, // 4 RGB LEDs distinguished by color

    // SERIAL (UART)
    input           FPGA_SERIAL_RX,
    output          FPGA_SERIAL_TX,

    // VGA style video Out, 444 RGB (Could dumb down to 4-bits elsewhere)
    output          VGA_HS_O,       // PMOD VGA: H_SYNC
    output          VGA_VS_O,       // PMOD VGA: V_SYNC
    output [3:0]    VGA_R,      // PMOD VGA: 4-bit red
    output [3:0]    VGA_G,      // PMOD VGA: 4-bit green
    output [3:0]    VGA_B,      // PMOD VGA: 4-bit blue

    // DDR3 Inouts
    inout [15:0]    ddr3_dq,        // inout WAS: [63:0] DDR2_D
    inout [1:0]     ddr3_dqs_n,     // inout WAS: [7:0] DDR2_DQS_N
    inout [1:0]     ddr3_dqs_p,     // inout WAS: [7:0] DDR2_DQS_P
    // DDR3 Outputs
    output [13:0]   ddr3_addr,      // output WAS: [12:0] DDR2_A
    output [2:0]    ddr3_ba,        // output WAS: [1:0] DDR2_BA
    output          ddr3_ras_n,     // output WAS: DDR2_RAS_B
    output          ddr3_cas_n,     // output WAS: DDR2_CAS_B
    output          ddr3_we_n,      // output WAS: DDR2_WE_B
    output [0:0]    ddr3_ck_p,      // output WAS: [1:0] DDR2_CLK_P
    output [0:0]    ddr3_ck_n,      // output WAS: [1:0] DDR2_CLK_N
    output [0:0]    ddr3_cke,       // output WAS: DDR2_CKE0
    output [0:0]    ddr3_cs_n,      // output WAS: DDR2_CS0_B,
    output [1:0]    ddr3_dm,        // output WAS: [7:0] DDR2_DM
    output [0:0]    ddr3_odt,       // output WAS: DDR2_ODT0
    output          ddr3_reset_n    // output WAS: ???
);

    // BUFFER the board clock (manually switch between Arty-A7 vs PYNQ)
    wire clk_in_100MHz; //, clk_in_100MHz_g;  // Arty-A7 or PYNQ ARM-CPU clk-out
    IBUF board_clk_ibuf (.I(CLK_100MHz), .O(clk_in_100MHz));  // Vivado refuses IBUFG!
    //BUFG board_clk_bufg (.I(clk_temp_1), .O(clk_in_100MHz_g));  // Must explicitly add BUFG.
    //wire clk_in_125MHz_G;  // PYNQ board clockDDR
    //IBUFG (.I(CLK_125MHz), .O(clk_in_125MHz_g));

    //TODO: Create a decent "reset tree" to resume components in a good sequence
    //NOTE: Early reset logic using board-clock "clk_in_100MHz"
    wire reset_top_clocks;
    ButtonClean #( .Width(1) ) clean_rst_top (
        .IN(!CK_RST_N),
        .Clock(clk_in_100MHz), .Reset(1'b0),
        .OUT(reset_top_clocks)
    );  //assign reset_top_clocks = !CK_RST_N;  // Top CLocks are first to come out of reset

    wire locked_top_clocks;  // Participate in startup sequence
    wire clk_mig_sys, clk_mig_ref, clk_cpu, clk_pix;
    clk_wiz_0 top_clocks (  // Generate various clocks for components
    // Clock in ports
        .clk_in_100MHz(clk_in_100MHz), //WAS: clk_in_100MHz_g),  // INPUT for Arty-A7 or PYNQ CPU
        //.clk_in_125MHz(clk_in_125MHz_g),  // INPUT for PYNQ (from board)
    // Clock out ports (rebuild clk_wiz if needs change)
        .clk_mig_100MHz     (clk_mig_sys),  // output MIG primary clk
        .clk_migref_200MHz  (clk_mig_ref),  // output REF clk for MIG
        .clk_pixel_40MHz    (clk_pix),      // output Pixel for VGA/DVI
        .clk_cpu_50MHz      (clk_cpu),      // output modest CPU speed
        // Status and control signals
        .reset(reset_top_clocks),  // input reset (ACTIVE HIGH)
        .locked(locked_top_clocks)  // output locked (ACTIVE HIGH)
    );  // NOTE: clk_wiz puts BUFG on its output clocks
//TODO: Figure out if we need BUFG on these clocks???

    // Then some other support components come out of reset (like DRAM)
    wire rst_cpu, rst_mig_sys_n, rst_pix, init_done;  // TODO: CPU comes out of reset after everything else
    Synchronizer #( .Width(1) ) sync_rst_mig_sys_n (
        .async_signal(!locked_top_clocks || !reset_top_clocks),
        .Clock(clk_mig_sys),  .sync_signal(rst_mig_sys_n));  // NOTE: This clock is bad when PLL not locked!
    Synchronizer #( .Width(1) ) sync_rst_cpu (
        .async_signal(!locked_top_clocks || !init_done ),
        .Clock(clk_cpu),  .sync_signal(rst_cpu));  // NOTE: This clock is bad when PLL not locked!
    Synchronizer #( .Width(1) ) sync_rst_pix (
        .async_signal(!locked_top_clocks || !init_done),
        .Clock(clk_pix),  .sync_signal(rst_pix));  // NOTE: This clock is bad when PLL not locked!


    // Debounce all switch & button signals
    wire [5:0] clean_combo;
    wire [1:0] switches;
    wire [3:0] buttons;
    ButtonClean #( .Width(6) ) clean_GPIO (  // 4 buttons + 2 switches = 6 signals
        .IN( { BUTTON[3:0], SWITCH[1:0] } ),  // Merge into 6-bit signal
        .Clock(clk_cpu), .Reset(rst_cpu),
        .OUT(clean_combo) );
    assign { buttons[3:0], switches[1:0] } = clean_combo;  // Separate the signals
//TODO: Let sync/debounce complete before letting CPU out of reset!

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
        assign stall_dip = switches[1]; //1'b0;  // TODO: Tie-in to a GPIO switch (and invert repeatedly)

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
            .rst_cpu_mem    (rst_cpu),
            .rst_cpu_bus    (rst_cpu),  //TODO: Distinguish "mem" & "bus" & CPU resets?
            .clk_mig_sys    (clk_mig_sys),
            .rst_mig_sys_n  (rst_mig_sys_n),
            .clk_mig_ref    (clk_mig_ref),
            .clk_pix        (clk_pix),
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

        assign video_ready = 1'b0;

        wire [3:0] CNTDEBUG;

        // MIPS 150 CPU
        MIPS150 #(
            .CPU_FREQ(CPU_FREQ),
            .BAUD_RATE(BAUD_RATE),
            .PC_BOOT(32'h4000_0000),
            .PC_ISR(32'hC000_0180),
            .CPU_CORE("MIPS")
        ) CPU (
            .clk(clk_cpu),  .rst(rst_cpu),  .stall(stall_top),
        // Serial (UART):
            .SerialRX(cpu_rx),  .SerialTX(cpu_tx),
        // Memory Caches:
            .dcache_addr(dcache_addr),  .icache_addr(icache_addr),
            .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),
            .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),
            .dcache_din (dcache_din ),  .icache_din (icache_din ),
            .dcache_dout(dcache_dout),  .icache_dout(icache_dout),
        // GPU:
            .pf_vframe  (pf_vframe),    .gp_vcode(gp_vcode),    .gp_vframe(gp_vframe),
            .pf_wframe  (pf_wframe),    .gp_wcode(gp_wcode),    .gp_wframe(gp_wframe),
                                        .gp_rcode(gp_rcode),
            .pf_status  (pf_status),                            .gp_status(gp_status),
            .irq_pf_frame(irq_pf_frame),    .irq_gp_done(irq_gp_done),

            .CNTDEBUG(CNTDEBUG)
        );

        assign stall_top = stall_dip || stall_icache || stall_dcache; //stall_cache

        assign LED[0] = buttons[0] ^ (locked_top_clocks & init_done);
        assign LED[1] = buttons[1] ^ (reset_top_clocks & rst_cpu);
        assign LED[2] = buttons[2] ^ stall_dcache;
        assign LED[3] = buttons[3] ^ stall_top;
        // TODO: Map RGB LEDs in constraints file and drive them with PWM
        wire [3:0] led_rgb_set;
        assign led_rgb_set = (switches[0]) ? DBG_dcache : CNTDEBUG;
        assign { led3_b, led2_r, led1_g, led0_b } = led_rgb_set ^ buttons;

    end endgenerate;

    //assign {VGA_HS_O,VGA_VS_O,VGA_R,VGA_G,VGA_B} = 14'd0; // No video yet
    VGATestPattern vga_gen (
        .PXL_CLK(clk_pix),
        .VGA_HS_O(VGA_HS_O),  .VGA_VS_O(VGA_VS_O),
        .VGA_R(VGA_R),  .VGA_G(VGA_G),  .VGA_B(VGA_B)
    );

endmodule
