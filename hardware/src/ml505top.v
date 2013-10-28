module ml505top
(
  input         USER_CLK,
//TIMESPEC TS_USER_CLK = PERIOD USER_CLK 10.0 ns HIGH 50%;
//Net USER_CLK    LOC = AH15  |  IOSTANDARD=LVCMOS33;
//Net USER_CLK    TNM_NET = USER_CLK;
  input         USER_RST,    // Extra connection added to passthrough to embedded stuff
//Net USER_RST    TIG;
//Net USER_RST    LOC = E9  |  IOSTANDARD=LVCMOS33  |  PULLUP;

  input         FPGA_SERIAL_RX,
//Net FPGA_SERIAL_RX      LOC = AG15  |  IOSTANDARD=LVCMOS33;
  output        FPGA_SERIAL_TX,
//Net FPGA_SERIAL_TX      LOC = AG20  |  IOSTANDARD=LVCMOS33;

  input [4:0]   GPIO_COMPPB,
//Net GPIO_COMPPB[0]      LOC = AJ6   |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPPB[1]      LOC = AJ7   |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPPB[2]      LOC = V8    |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPPB[3]      LOC = AK7   |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPPB[4]      LOC = U8    |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;

  output [7:0]  GPIO_LED,
//Net GPIO_LED[7]         LOC = AE24  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[6]         LOC = AD24  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[5]         LOC = AD25  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[4]         LOC = G16   |  IOSTANDARD=LVCMOS25  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[3]         LOC = AD26  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[2]         LOC = G15   |  IOSTANDARD=LVCMOS25  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[1]         LOC = L18   |  IOSTANDARD=LVCMOS25  |  SLEW=SLOW  |  DRIVE=2;
//Net GPIO_LED[0]         LOC = H18   |  IOSTANDARD=LVCMOS25  |  SLEW=SLOW  |  DRIVE=2;

  output [4:0]  GPIO_COMPLED,
//Net GPIO_COMPLED[0]     LOC = E8    |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPLED[1]     LOC = AF23  |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPLED[2]     LOC = AG12  |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPLED[3]     LOC = AG23  |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_COMPLED[4]     LOC = AF13  |  IOSTANDARD=LVCMOS33  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;

  input [7:0]   GPIO_DIP,
//Net GPIO_DIP[0]         LOC = U25   |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[1]         LOC = AG27  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[2]         LOC = AF25  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[3]         LOC = AF26  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[4]         LOC = AE27  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[5]         LOC = AE26  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[6]         LOC = AC25  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;
//Net GPIO_DIP[7]         LOC = AC24  |  IOSTANDARD=LVCMOS18  |  SLEW=SLOW  |  DRIVE=2  |  PULLDOWN;

  output [12:0] DDR2_A,
  output [1:0]  DDR2_BA,
  output        DDR2_CAS_B,
  output        DDR2_CKE,
  output [1:0]  DDR2_CLK_N,
  output [1:0]  DDR2_CLK_P,
  output        DDR2_CS_B,
  inout  [63:0] DDR2_D,
  output [7:0]  DDR2_DM,
  inout  [7:0]  DDR2_DQS_N,
  inout  [7:0]  DDR2_DQS_P,
  output        DDR2_ODT,
  output        DDR2_RAS_B,
  output        DDR2_WE_B,
    
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

    wire button_reset, debug_reset, rst_or_init;
    wire button_stall, debug_stall, any_stall;

// "MIPSY" MIPS150 CPU inter-connects
    wire M_SERIAL_RX, M_SERIAL_TX;

// "PLOP" MicroBlaze CPU inter-connects
    wire P_SERIAL1_RX, P_SERIAL1_TX; //JTAG-to-SERIAL relay UART
    wire P_SERIAL2_RX, P_SERIAL2_TX; //Extra UART
    wire [31: 0] P_gpi1 = 32'd0;    //IN-to-PLOP
    wire [31: 0] P_gpo1;            //OUT-from-PLOP

// Selector for physical serial vs. debug serial (via JTAG UART)
    wire SERIAL_JTAG = 1'b0; //TODO: Tie to a configuration input


  reg [3:0]  reset_r = 4'b0;
  reg [25:0] count_r = 26'b0;

  wire [3:0]  next_reset_r;
  wire [25:0] next_count_r;

  wire user_clk_g;

  wire cpu_clk;
  wire cpu_clk_g;

  wire clk0;
  wire clk0_g;

  wire clk90;
  wire clk90_g;

  wire clkdiv0;
  wire clkdiv0_g;

  wire clk200;
  wire clk200_g;

  wire pll_lock;

  wire clk50;
  wire clk50_g;

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
    .RST(1'b0) // Would it hurt to use USER_RST?
  );

  IBUFG user_clk_buf ( .I(USER_CLK), .O(user_clk_g) );
  BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
  BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
  BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
  BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );
  BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
  BUFG  clkdiv50_buf ( .I(clk50),    .O(clk50_g)    );

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
  wire         mem_stall;
  wire         mem_init_done;
    assign any_stall = mem_stall || man_stall || debug_stall;
    assign rst_or_init = rst || ~mem_init_done;

// CP3+
  wire [31:0]  bypass_addr;
  wire [31:0]  bypass_din;
  wire [3:0]   bypass_we;
  wire         video_ready;
  wire         dvi_video_ready;
  wire         video_valid;
  wire [23:0]  video;
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

  Memory150 #(.SIM_ONLY(1'b0)) mem_arch(
      .cpu_clk_g(cpu_clk_g),
      .clk0_g(clk0_g),
      .clk90_g(clk90_g),
      .clkdiv0_g(clkdiv0_g),
      .clk200_g(clk200_g),
      .rst(fifo_reset),
      .init_done(mem_init_done),
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
      .instruction(instruction),

`ifdef __COLT45_pre3
      .bypass_addr(bypass_addr),
      .bypass_we  (bypass_we  ),
      .bypass_din (bypass_din ),
      .clk50_g(clk50_g),

      .video      (video      ),
      .video_ready(video_ready),
      .video_valid(video_valid),
      .filler_color(filler_color),
      .filler_valid(filler_valid),
      .filler_ready(filler_ready),
      .line_ready(line_ready),
      .line_color(line_color),
      .line_point(line_point),
      .line_color_valid(line_color_valid),
      .line_x0_valid(line_x0_valid),
      .line_y0_valid(line_y0_valid),
      .line_x1_valid(line_x1_valid),
      .line_y1_valid(line_y1_valid),
      .line_trigger(line_trigger),
`endif
      .stall(mem_stall)
    );

// CP3+
  DVI #(
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
    .Clock(                     cpu_clk_g),
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
    /* Ready/Valid interface for 24-bit pixel values */
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
// CP3+
    .bypass_addr( bypass_addr ),    .bypass_we  ( bypass_we ),
    .bypass_din ( bypass_din  ),
    .filler_color   (filler_color),
    .filler_valid   (filler_valid),
    .filler_ready   (filler_ready),
    .line_ready     (line_ready),
    .line_color     (line_color),
    .line_point     (line_point),
    .line_color_valid(line_color_valid),
    .line_x0_valid  (line_x0_valid),
    .line_y0_valid  (line_y0_valid),
    .line_x1_valid  (line_x1_valid),
    .line_y1_valid  (line_y1_valid),
    .line_trigger   (line_trigger),
// Shared
    .stall(any_stall)
  );


`ifdef COLT45_PLOP
    plop PLOP ( // Plop a helper MicroBlaze CPU (relays debugger JTAG-SERIAL link)
        .CLOCK_REF_100MHz(user_clk_g),
        .RESET_BOARD(USER_RST), .RESET_AUX(1'b0),
        .MB_HALTED(), .RESET_PERIPHERAL(), //OUTs
        // Two UARTs primary from JTAG-to-SERIAL debug link
        .SERIAL1_RX(P_SERIAL1_RX), .SERIAL1_TX(P_SERIAL1_TX),
        .SERIAL2_RX(P_SERIAL2_RX), .SERIAL2_TX(P_SERIAL2_TX),
        // GPIO (32-bits each way)
        .GPI1(P_gpi1),  .GPO1(P_gpo1)
    ) /* synthesis syn_noprune=1 */;
`else
    assign P_SERIAL1_TX = 1'b1, P_SERIAL2_TX = 1'b1;
    assign P_gpo1 = 32'd0;
`endif


`ifdef COLT45_DEBUG
    wire [35: 0] CS_CONTROL0;
    wire [ 7: 0] cs_IN, cs_OUT, cs_aIN, cs_aOUT;
    chipscope_icon CS_ICON (
        .CONTROL0(CS_CONTROL0) // INOUT BUS [35:0]
    ) /* synthesis syn_noprune=1 */;
    chipscope_vio CS_VIO (
        .CONTROL(CS_CONTROL0),  .CLK(cpu_clk_g),
        .SYNC_IN( cs_IN ),      .SYNC_OUT( cs_OUT ), // [7:0]
        .ASYNC_IN(cs_aIN),      .ASYNC_OUT(cs_aOUT) // [7:0]
    ) /* synthesis syn_noprune=1 */;

    assign cs_aIN = { rst_or_init, any_stall, 1'b0, 1'b1,
                        button_reset, button_stall, 1'b1, 1'b0 };
    assign cs_IN = cs_aIN;
    assign debug_reset = cs_aOUT[7];
    assign debug_stall = cs_OUT[6];
`else
    assign debug_reset = 1'b0;
    assign debug_stall = 1'b0;
`endif


// Patch course IO into generic IO board pins
`ifndef COLT45_StallSkip
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
    assign GPIO_LED = {5'b00000, any_stall, pll_lock, mem_init_done};
    //if SERIAL_JTAG then MIPSY talks to PLOP UART1 & PLOP UART2 gets physical UART
    assign FPGA_SERIAL_TX = (SERIAL_JTAG) ? P_SERIAL2_TX    : M_SERIAL_TX;
    assign M_SERIAL_RX    = (SERIAL_JTAG) ? P_SERIAL1_TX    : FPGA_SERIAL_RX;
    assign P_SERIAL1_RX   = (SERIAL_JTAG) ? M_SERIAL_TX     : P_SERIAL2_TX;
    assign P_SERIAL2_RX   = (SERIAL_JTAG) ? FPGA_SERIAL_RX  : P_SERIAL1_TX;

endmodule
