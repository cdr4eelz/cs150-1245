module ml505top
(
  input         FPGA_SERIAL_RX,
  output        FPGA_SERIAL_TX,
  input [4:0]   GPIO_COMPPB,
  input [7:0]   GPIO_DIP,
  output [4:0]  GPIO_COMPLED,
//input         USER_RST, // To passthrough to embedded IP-cores
  input         USER_CLK,

  output [7:0]  GPIO_LED,

// CP2+
  output [12:0] ddr2_a, //Lower case just to match MIG ucf PIN convention
  output [1:0]  ddr2_ba,
  output        ddr2_cas_n,
  output [0:0]  ddr2_cke,
  output [1:0]  ddr2_ck_n,
  output [1:0]  ddr2_ck,
  output [0:0]  ddr2_cs_n,
  inout  [63:0] ddr2_dq,
  output [7:0]  ddr2_dm,
  inout  [7:0]  ddr2_dqs_n,
  inout  [7:0]  ddr2_dqs,
  output [0:0]  ddr2_odt,
  output        ddr2_ras_n,
  output        ddr2_we_n,

// CP4+
  output [11:0] DVI_D,
  output        DVI_DE,
  output        DVI_H,
  output        DVI_RESET_B,
  output        DVI_V,
  output        DVI_XCLK_N,
  output        DVI_XCLK_P,

  inout         IIC_SCL_VIDEO,
  inout         IIC_SDA_VIDEO
);
    wire USER_RST = 1'b1; //Disable (active_low)

    wire button_reset, rst_or_init, rst;
    wire button_stall, any_stall;

// BRK tap
    wire debug_reset, debug_stall, debug_brk, debug_jog;
    wire [0:1023] debug_trace;
    wire [35: 0] SCOPE_CPU;

// UART crosswork
    wire M_SERIAL_RX, M_SERIAL_TX;
    wire P_SERIAL1_RX, P_SERIAL1_TX;
    wire P_SERIAL2_RX, P_SERIAL2_TX;

// Selector for physical serial vs. debug serial (via JTAG UART)
    wire SERIAL_JTAG, BRK_MASTER;


  reg [3:0]  reset_r = 4'b0;
  reg [25:0] count_r = 26'b0;

  wire [3:0]  next_reset_r;
  wire [25:0] next_count_r;

    // Global clock lines (use the _g since are buffered)
    wire user_clk_g, pll_lock;
    wire clk0_g, clk90_g, clkdiv0_g, clk200_g, clk50_g;
    wire cpu_clk_g, plop_clk_g; //For the MIPSY & PLOP

  always @(posedge cpu_clk_g)
  begin
    reset_r <= next_reset_r;
    count_r <= next_count_r;
  end

  assign next_reset_r = {reset_r[2:0], button_reset | debug_reset};

  assign rst = (count_r == 26'b1) | ~pll_lock;

  assign next_count_r
    = (count_r == 26'b0) ? (reset_r[3] ? 26'b1 : 26'b0)
    :                      count_r + 1;

  // Reset shift register:
  reg [2:0] rst_sr;
  wire fifo_reset; // fifo_reset resets fifos... reset_fifo is a fifo for the reset signal.
  assign fifo_reset = rst | (|rst_sr);
  always @(posedge cpu_clk_g) begin
    rst_sr <= {rst_sr[1:0], rst};
  end


// Manual stalling test (checkpoint 1):
    reg man_stall;
    wire man_stall_toggle;
    always@(posedge cpu_clk_g) begin
        if(rst) begin
            man_stall <= 1'b0;
        end else begin
            if(man_stall_toggle) begin
                man_stall <= ~man_stall;
            end else begin
                man_stall <= 1'b0;
            end
        end
    end

// Debug stall with one-shot "jog"
    reg debug_jog_fired;
    always @(posedge cpu_clk_g) begin
        if (rst_or_init || ~debug_jog)
            debug_jog_fired <= 1'd0;
        else if (~any_stall)
            debug_jog_fired <= 1'd1;
        // else hold value
    end
    wire debug_stall_not_jog = ((debug_stall && !debug_jog) || debug_jog_fired);


// CP2+
  wire  [31:0] dcache_addr;
  wire  [31:0] icache_addr;
  wire  [3:0]  dcache_we;
  wire  [3:0]  icache_we;
  wire         dcache_re;
  wire         icache_re;
  wire  [31:0] dcache_din;
  wire  [31:0] icache_din;
  wire [31:0]  dcache_dout;
  wire [31:0]  instruction;
  wire         stall;
// CP4+
  wire         video_ready;
//  wire         dvi_video_ready;
  wire         video_valid;
  wire [23:0]  video;
/* Probably leftover from pre-GraphicsController/RequestProcessor patch
  wire [23:0]  filler_color;
  wire         filler_ready;
  wire         filler_valid;
  wire         line_ready;
  wire  [31:0] line_color;
  wire  [9:0]  line_point;
  wire         line_color_valid;
  wire         line_x0_valid;
  wire         line_y0_valid;
  wire         line_x1_valid;
  wire         line_y1_valid;
  wire         line_trigger;
*/
  wire fb0;
   wire frame_interrupt;
   wire [31:0] gp_code;
   wire [31:0] gp_frame;
   wire        gp_valid;

    wire         init_done; //Missing decl in skeleton
//Might help to delay master rst_or_init against slowest clock & release early in phase
    assign rst_or_init = rst || ~init_done;
    assign any_stall = stall;// || man_stall || debug_stall_not_jog;

  Memory150 #(.SIM_ONLY(1'b0)) mem_arch(
      .cpu_clk_g(cpu_clk_g),
      .clk0_g(clk0_g),
      .clk200_g(clk200_g),
      .clkdiv0_g(clkdiv0_g),
      .clk90_g(clk90_g),
      .clk50_g(clk50_g),
      .rst(fifo_reset),
      .init_done(init_done),
        .DDR2_A     (ddr2_a), //Lower case just to match MIG ucf PIN convention
        .DDR2_BA    (ddr2_ba),
        .DDR2_CAS_B (ddr2_cas_n),
        .DDR2_CKE   (ddr2_cke),
        .DDR2_CLK_N (ddr2_ck_n),
        .DDR2_CLK_P (ddr2_ck),
        .DDR2_CS_B  (ddr2_cs_n),
        .DDR2_D     (ddr2_dq),
        .DDR2_DM    (ddr2_dm),
        .DDR2_DQS_N (ddr2_dqs_n),
        .DDR2_DQS_P (ddr2_dqs),
        .DDR2_ODT   (ddr2_odt),
        .DDR2_RAS_B (ddr2_ras_n),
        .DDR2_WE_B  (ddr2_we_n),
      .locked(pll_lock),
      .dcache_addr(dcache_addr),
      .icache_addr(icache_addr),
      .dcache_we  (dcache_we  ),
      .icache_we  (icache_we  ),
      .dcache_re  (dcache_re  ),
      .icache_re  (icache_re  ),
      .dcache_din (dcache_din ),
      .icache_din (icache_din ),
      .dcache_dout(dcache_dout),
      .icache_dout(instruction),
      .stall      (stall      ),
//CP4+
      .video      (video      ),
      .video_ready(video_ready),
      .video_valid(video_valid),
      .cpu_gp_code(gp_code),
      .cpu_gp_frame(gp_frame),
      .cpu_gp_valid(gp_valid),
      .frame_interrupt(frame_interrupt)
    );

// CP4+
    DVI #(
// Resolution         Width   FrontH  PulseH  BackH   Height  FrontV  PulseV  BackV   ClockFreq
// VESA 800x600,72Hz: 1040    56      120     64      666     37      6       23      50000000
        .ClockFreq(                 50_000_000), //50 MHz
        .Width(                     1040),
        .FrontH(                    56),
        .PulseH(                    120),
        .BackH(                     64),
        .Height(                    666),
        .FrontV(                    37),
        .PulseV(                    6),
        .BackV(                     23)
    ) dvi(
        .Clock(                     clk50_g),//NOTE: Was cpu_clk_g in skeleton
        .Reset(                     rst_or_init),
        .DVI_D(                     DVI_D),
        .DVI_DE(                    DVI_DE),
        .DVI_H(                     DVI_H),
        .DVI_V(                     DVI_V),
        .DVI_RESET_B(               DVI_RESET_B),
        .DVI_XCLK_N(                DVI_XCLK_N),
        .DVI_XCLK_P(                DVI_XCLK_P),
        .I2C_SCL_DVI(               IIC_SCL_VIDEO),
        .I2C_SDA_DVI(               IIC_SDA_VIDEO),
    // Ready/Valid interface for 24-bit pixel values
        .Video(                     video),
        .VideoReady(                video_ready),
        .VideoValid(                video_valid)
    );

`ifndef CPUTYPE
`define CPUTYPE MIPS150 // MIPS150/DumpMemCPU/DumpMEMIOCPU
`endif
`CPUTYPE CPU(
    .clk( cpu_clk_g ), .rst( rst_or_init ),
    .FPGA_SERIAL_RX(M_SERIAL_RX), .FPGA_SERIAL_TX(M_SERIAL_TX),
// CP2+
    .dcache_addr( dcache_addr ),    .icache_addr( icache_addr ),
    .dcache_we  ( dcache_we   ),    .icache_we  ( icache_we   ),
    .dcache_re  ( dcache_re   ),    .icache_re  ( icache_re   ),
    .dcache_din ( dcache_din  ),    .icache_din ( icache_din  ),
    .dcache_dout( dcache_dout ),    .instruction( instruction ),
    .stall(any_stall),

// CP4+
    .gp_code(cpu_gp_code),
    .gp_frame(cpu_gp_frame),
    .gp_valid(cpu_gp_valid),
    .frame_interrupt(frame_interrupt),
//add GP_CODE, GP_FRAME, and GP_valid io here and pixel feeder interrupt

//BRK tap
    .brk(debug_brk), .trace(debug_trace), .SCOPE_CPU(SCOPE_CPU)
);


//TODO: Move all/most debug,BRK,PLOP into MIPSY & re-standardize ml505top.v

`ifdef COLT45_PLOP
    // Global PLOP lines
    wire PLOP_RST_AUX, PLOP_RST_Periph;
    wire MM0_IRQ0, MB0_IRQ1, MB0_Error, MB0_Halted;
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

    plop PLOP ( // Plop in helper MicroBlaze (JTAG-SERIAL relay & BRK monitor)
//      .CLK_REF_100MHz ( user_clk_g ), //IN
        .CLK_MIPSY      ( cpu_clk_g ), //IN
        .CLK_PLOP       ( plop_clk_g ), //IN
        .CLK_Locked     ( pll_lock ), //IN
        .RST_PHY_LO     ( USER_RST ), //IN
        .RST_AUX_HI     ( PLOP_RST_AUX ), //IN
        .RST_Periph_HI  ( PLOP_RST_Periph ), //OUT

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
        .UART_PHY_RX      ( UART_PHY_RX ), //IN
        .UART_PHY_Tx      ( UART_PHY_Tx ), //OUT
        .UART_MIPSY_RX    ( UART_MIPSY_RX ), //IN
        .UART_MIPSY_Tx    ( UART_MIPSY_Tx ) //OUT
    ) /* synthesis syn_noprune=1 */;



    // PLOP patchwork
    assign PLOP_RST_AUX = 1'b0,
            MB0_IRQ0 = 1'b0,
            MB0_IRQ1 = 1'b0; // PLOP_RST_Periph, MB0_Error, MB0_Halted
    assign BIOS_BRAM_DIN = 32'd0; // ,,,
    assign BRK_BRAM_RST = USER_RST, //TODO: Becomes our internal reset/init_done
            BRK_BRAM_CLK = cpu_clk_g, //TODO: Consider faster clock just for BRK
            BRK_BRAM_EN = 1'b0,
            BRK_BRAM_WEN = 4'b0000,
            BRK_BRAM_ADDR = 32'h00000000,
            BRK_BRAM_DOUT = 32'd0; // BRK_BRAM_Din
    assign BRK_DCR_DRBUS = 32'd0; // ,,,
    assign GPI1_32 = 32'd0, GPI2_32 = 32'd0, GPI3_32 = 32'd0, GPI4_32 = 32'd0; // GPo<n>_32

    // Simple renaming/passthrough for ml505top names (appropriate for sex of connection)
    assign  UART_MIPSY_RX = P_SERIAL1_RX,
            P_SERIAL1_TX  = UART_MIPSY_Tx,
            UART_PHY_RX   = P_SERIAL2_RX,
            P_SERIAL2_TX = UART_PHY_Tx;
`else
    assign P_SERIAL1_TX = 1'b1, P_SERIAL2_TX = 1'b1;
`endif


`ifdef COLT45_BRK
/*  BRK coordinator:

    Intercept/Trace relative to BRK (towards CPU):
        debug_reset-o1
        debug_stall-o1
        debug_brk-o1
        debug_jog-o1
        trace-i1024
    { If need to tap elements outside CPU, perhaps arrange passthrough or tap? }

    Control/Reporting relative to BRK (towards Monitor):
        action-i8:
        status-o8:
        enable-i8:
        hit-o8:
        trace-o1024: (interrogated with dsel-i5/dval-o32 or ssel-i2/sval-o256)
        match-i256: (first 4 words simple equality w/trace; ideal allows fancier masking/edges)
        record-oBRAM: (accumulated traces or watched items at real-speed, expose full BRAM?)
    Convenient to pack action/enable/msel/dsel/ssel/rsel/ser into one 32-bit input!
    { Can we accumulate snapshots at "real time" big/filtered enough to be useful (or just use CS)? }
    { Is realistic to dump trace(s) as serial like I2C? }
    { Little from enclosing environment, perhaps DDR/DVI and SW/LED stuff? }
    Layout "trace" as 4 segments (256-bit) x 8 words (32-bit): (current is loosly Global/WF|DX|M|rare)
        seg0: Global/Inter-Stage
        seg1: StageWF
        seg2: StageDX
        seg3: StageM
*/

//TODO:Overcome trouble with bitvector selection,address-order,big-case,or something
    function automatic [0:255] GET_SEGMENT (
        input [1:0] ssel,
        input [0:1023] allbits
    );
        begin
            case (ssel)
                2'd3: GET_SEGMENT = allbits[768:1023];
                2'd2: GET_SEGMENT = allbits[512: 767];
                2'd1: GET_SEGMENT = allbits[256: 511];
                default: GET_SEGMENT = allbits[0:255];
            endcase
        end
    endfunction
    
    function automatic [0:31] GET_DATUM (
        input [2:0] dsel,
        input [0:255] segbits
    );
        begin
            case (dsel)
                3'd7: GET_DATUM = segbits[224:255];
                3'd6: GET_DATUM = segbits[192:223];
                3'd5: GET_DATUM = segbits[160:191];
                3'd4: GET_DATUM = segbits[128:159];
                3'd3: GET_DATUM = segbits[ 96:127];
                3'd2: GET_DATUM = segbits[ 64: 95];
                3'd1: GET_DATUM = segbits[ 32: 63];
                default: GET_DATUM = segbits[0:31];
            endcase
        end
    endfunction

    wire [35: 0] CS0, CS1;
    cs_icon_3 CS_ICON (
        .CONTROL0(CS0), .CONTROL1(CS1), .CONTROL2(SCOPE_CPU) // INOUT BUS [35:0]
    ) /* synthesis syn_noprune=1 */;

    wire [ 7: 0] BRK_ACTION, BRK_EN /* synthesis syn_noprune=1 */;
    wire [ 7: 0] BRK_STATUS, BRK_HIT /* synthesis syn_noprune=1 */;
    wire [0:255] BRK_MATCH, BRK_WATCH /* synthesis syn_noprune=1 */;

    wire [ 7: 0] BRK_DSEL; // Ignores high 3-bits
    reg  [ 0:31] BRK_DVAL;
    cs_vio_brk CS_VIO_BRK ( .CONTROL(CS0),  .CLK(cpu_clk_g),
        .ASYNC_OUT( {BRK_DSEL[7:0], BRK_EN[7:0], BRK_ACTION[7:0]} ),  // OUT BUS [23:0]
        .ASYNC_IN( {BRK_DVAL[0:31], BRK_HIT[7:0], BRK_STATUS[7:0]} ), // IN BUS [47:0]
        .SYNC_OUT(  BRK_MATCH[0:255] ), // OUT BUS [255:0]
        .SYNC_IN(   BRK_WATCH[0:255] )  // IN BUS [255:0]
    ) /* synthesis syn_noprune=1 */;
    always @(*) BRK_DVAL = GET_DATUM(BRK_DSEL[2:0], GET_SEGMENT(BRK_DSEL[4:3], debug_trace));

    wire [ 1: 0] BRK_SSEL;
    reg  [0:255] BRK_SVAL;
    cs_vio_256 CS_VIO_256 ( .CONTROL(CS1),
        .ASYNC_OUT( BRK_SSEL[1:0] ), // OUT BUS [1:0]
        .ASYNC_IN( BRK_SVAL[0:255] ) // IN BUS [255:0]
    ) /* synthesis syn_noprune=1 */;
    always @(*) BRK_SVAL = GET_SEGMENT(BRK_SSEL, debug_trace);

    assign BRK_WATCH = debug_trace[0:255];
    assign BRK_HIT[0] = (BRK_MATCH[(0<<5)+:32]==BRK_WATCH[(0<<5)+:32]);
    assign BRK_HIT[1] = (BRK_MATCH[(1<<5)+:32]==BRK_WATCH[(1<<5)+:32]);
    assign BRK_HIT[2] = (BRK_MATCH[(2<<5)+:32]==BRK_WATCH[(2<<5)+:32]);
    assign BRK_HIT[3] = (BRK_MATCH[(3<<5)+:32]==BRK_WATCH[(3<<5)+:32]);
        //TODO:DOBranch_DX_WF_ (use for branch-match), skip rd1/2 & coopt as masks
    assign BRK_HIT[4] = 1'b0;
    assign BRK_HIT[5] = 1'b0;
    assign BRK_HIT[6] = 1'b0;
    assign BRK_HIT[7] = 1'b0;
    wire BRK_isEN = |BRK_EN;
    wire BRK_isHIT = |(BRK_HIT & BRK_EN);

    assign BRK_STATUS[7:0] = { rst_or_init, any_stall, button_reset, button_stall,
                                debug_brk, debug_jog, BRK_isEN, BRK_isHIT };

    assign debug_reset = BRK_ACTION[7];
    assign debug_stall = (BRK_ACTION[6] || BRK_isHIT);
    assign debug_brk = BRK_ACTION[5];
    assign debug_jog = BRK_ACTION[4];
    assign SERIAL_JTAG = BRK_ACTION[1];
    assign BRK_MASTER = BRK_ACTION[0];
`else
    assign {debug_reset,debug_stall,debug_brk,debug_jog} = 4'b0000;
    assign {BRK_MASTER,SERIAL_JTAG} = 2'b00;

//    cs_icon_1 CS_ICON (
//        .CONTROL0(SCOPE_CPU) // INOUT BUS [35:0]
//    ) /* synthesis syn_noprune=1 */;
`endif


// Patch course IO into generic IO board pins
`ifdef COLT45_StallFORCE
    assign man_stall_toggle = 1'b1;
`else
`ifdef COLT45_StallDIP
    assign man_stall_toggle = GPIO_DIP[0];
`else
    assign man_stall_toggle = 1'b0;
`endif
`endif
    assign button_reset = GPIO_COMPPB[0];   // Center PushButton on "compass"
    //assign button_reset = GPIO_COMPPB[2];   // South PushButton on "compass"
    assign GPIO_COMPLED = {button_reset, 1'b0, man_stall_toggle, 2'b00};
    assign GPIO_LED = {5'b00000, any_stall, pll_lock, init_done};
    //if SERIAL_JTAG then MIPSY talks to PLOP UART1 & PLOP UART2 gets physical UART
    assign FPGA_SERIAL_TX = (SERIAL_JTAG) ? P_SERIAL2_TX    : M_SERIAL_TX;
    assign M_SERIAL_RX    = (SERIAL_JTAG) ? P_SERIAL1_TX    : FPGA_SERIAL_RX;
    assign P_SERIAL1_RX   = (SERIAL_JTAG) ? M_SERIAL_TX     : P_SERIAL2_TX;
    assign P_SERIAL2_RX   = (SERIAL_JTAG) ? FPGA_SERIAL_RX  : P_SERIAL1_TX;
    //NOTE: Because we are AT the border between external and internal UART
    //      connections, the FPGA_SERIAL_xx names appear flipped.


    // Raw clock lines (unbuffered, don't use elsewhere)
    wire pll_fb, clk50, clk0, clk90, clkdiv0, clk125;
    PLL_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN_PERIOD(10.0), //Input Freq 100MHz
        .DIVCLK_DIVIDE(2), .CLKFBOUT_MULT(20), .CLKFBOUT_PHASE(0.0),
        //INTERNAL REFERENCE: --=> 100 / 2 * 20 = 1000 MHz (basis for each below):

        .CLKOUT0_DIVIDE(20), .CLKOUT0_DUTY_CYCLE(0.5), .CLKOUT0_PHASE(0.0),
        //#0:clk50=cpu_clk: 1000 / 20 = 50 MHz

        .CLKOUT1_DIVIDE(5), .CLKOUT1_DUTY_CYCLE(0.5), .CLKOUT1_PHASE(0.0),
        //#1:clk0=clk200: 1000 / 5 => 200 MHz 50/50 @0 deg

        .CLKOUT2_DIVIDE(5), .CLKOUT2_DUTY_CYCLE(0.5), .CLKOUT2_PHASE(90.0),
        //#2:clk90: 1000 / 5 => 200 MHz 50/50 @90 deg

        .CLKOUT3_DIVIDE(10), .CLKOUT3_DUTY_CYCLE(0.5), .CLKOUT3_PHASE(0.0),
        //#3:clkdiv0: 1000 / 10 => 100 MHz 50/50 @0 deg

        .CLKOUT4_DIVIDE(8), .CLKOUT4_DUTY_CYCLE(0.5), .CLKOUT4_PHASE(90.0),
        //#4:clk125: 1000 / 8 => 125 MHz 50/50 @90 deg

        .COMPENSATION("SYSTEM_SYNCHRONOUS"), .REF_JITTER(0.100)
    ) user_clk_pll (
        .CLKIN(user_clk_g), .RST(~USER_RST), //WAS: 1'b0
        .CLKOUT0(clk50), .CLKOUT1(clk0),
        .CLKOUT2(clk90), .CLKOUT3(clkdiv0), .CLKOUT4(clk125),
        .CLKFBIN(pll_fb), .CLKFBOUT(pll_fb), .LOCKED(pll_lock)
    );

    // Buffer reset/clocks for general use
    IBUFG user_clk_buf ( .I(USER_CLK), .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(clk50),    .O(cpu_clk_g)  );
    BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
    BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
    BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );
    BUFG  clk200_buf   ( .I(clk0),     .O(clk200_g)   );
    BUFG  clk50_buf    ( .I(clk50),    .O(clk50_g)    );
    BUFG  clk125_buf   ( .I(clk125),   .O(plop_clk_g) );
// synthesis attribute keep of cpu_clk_g is "true";

endmodule
