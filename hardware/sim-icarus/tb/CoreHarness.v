`timescale 1ns/1ps
// Minimal CPU-core harness: CPUMIPS + RegFile + COP0150 with behavioral memories,
// no MemBank/BRAM cores/UART (so no Xilinx libraries needed).
//   PC_BOOT 0x6000_0000: instructions from MAIN_HEX (word array, PC[13:2])
//   PC 0xC000_xxxx     : instructions from ISR_HEX  (ISR entry 0xC000_0180)
//   data 0x5xxx_xxxx   : "x5" scratch RAM (no stall)      -> x5[addr[13:2]]
//   data 0x1xxx_xxxx   : "ddr" RAM; a store here stalls the CPU for NSTALL cycles
//                        starting the next cycle (like Cache.v's we_hold)
// The instruction port is not gated by stall (like MemBank port b); the data
// port is enabled by !stall && (load||store), like MemBank's "ena".
// irq_tx is a level input wired to COP0's UATX interrupt line.
module CoreHarness #(
    parameter NSTALL   = 4,
    parameter MAIN_HEX = "main.hex",
    parameter ISR_HEX  = "isr.hex",
    parameter WORDS    = 4096
)(
    input clk, rst, irq_tx
);
  reg [7:0] stall_cnt = 0;
  wire stall = (stall_cnt != 0);

  wire REGFILE_we; wire [31:0] REGFILE_wd, REGFILE_rd1, REGFILE_rd2; wire [4:0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
  wire COP0_we; wire [31:0] COP0_wd, COP0_rd; wire [4:0] COP0_ra; wire [31:0] intr_pc; wire intr_handled, intr_request;
  wire [31:0] IMEM_ADDR, DMEM_ADDR; reg [31:0] IMEM_DATA, DMEM_DATA;
  wire MemToRegDX_, MemWriteDX_, PCinBIOSDX_; wire [31:0] _WDataMasked; wire [3:0] _WriteMask;

  RegFile regfile(.clk(clk), .wa(REGFILE_wa), .wd(REGFILE_wd), .we(REGFILE_we),
    .ra1(REGFILE_ra1), .rd1(REGFILE_rd1), .ra2(REGFILE_ra2), .rd2(REGFILE_rd2));
  COP0150 cop0(.clk(clk), .rst(rst), .ena(1'b1), .COP0_we(COP0_we), .COP0_wd(COP0_wd), .COP0_rd(COP0_rd), .COP0_ra(COP0_ra),
    .intr_pc(intr_pc), .intr_handled(intr_handled), .intr_request(intr_request),
    .irq_UARX(1'b0), .irq_UATX(irq_tx), .irq_pf_frame(1'b0), .irq_gp_done(1'b0));
  CPUMIPS #(.PC_BOOT(32'h6000_0000)) core(.clk(clk), .rst(rst), .stall(stall),
    .REGFILE_we(REGFILE_we), .REGFILE_wa(REGFILE_wa), .REGFILE_wd(REGFILE_wd),
    .REGFILE_ra1(REGFILE_ra1), .REGFILE_ra2(REGFILE_ra2), .REGFILE_rd1(REGFILE_rd1), .REGFILE_rd2(REGFILE_rd2),
    .COP0_we(COP0_we), .COP0_wd(COP0_wd), .COP0_rd(COP0_rd), .COP0_ra(COP0_ra),
    .intr_pc(intr_pc), .intr_handled(intr_handled), .intr_request(intr_request),
    .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR), .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
    .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_), .PCinBIOSDX_(PCinBIOSDX_),
    ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask));

  reg [31:0] mainm[0:WORDS-1], isrm[0:WORDS-1], x5[0:WORDS-1], ddr[0:WORDS-1];
  integer i;
  initial begin
    for (i=0;i<WORDS;i=i+1) begin mainm[i]=0; isrm[i]=0; x5[i]=0; ddr[i]=0; end
    $readmemh(MAIN_HEX, mainm); $readmemh(ISR_HEX, isrm);
  end
  always @(posedge clk) IMEM_DATA <= (IMEM_ADDR[31:28]==4'hC) ? isrm[IMEM_ADDR[13:2]] : mainm[IMEM_ADDR[13:2]];
  wire dhot = (MemToRegDX_ || MemWriteDX_);
  integer b;
  always @(posedge clk) if (!stall && dhot) begin
    case (DMEM_ADDR[31:28])
      4'h5: begin DMEM_DATA <= x5[DMEM_ADDR[13:2]];
              for (b=0;b<4;b=b+1) if (_WriteMask[b]) x5[DMEM_ADDR[13:2]][8*b +: 8] <= _WDataMasked[8*b +: 8]; end
      4'h1: begin DMEM_DATA <= ddr[DMEM_ADDR[13:2]];
              for (b=0;b<4;b=b+1) if (_WriteMask[b]) ddr[DMEM_ADDR[13:2]][8*b +: 8] <= _WDataMasked[8*b +: 8]; end
      default: DMEM_DATA <= 32'hDEAD_BEEF;
    endcase
  end
  always @(posedge clk) begin
    if (stall_cnt != 0) stall_cnt <= stall_cnt - 1;
    else if (dhot && |_WriteMask && DMEM_ADDR[31:28]==4'h1) stall_cnt <= NSTALL;
  end
endmodule
