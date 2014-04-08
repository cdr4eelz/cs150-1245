// Simple adapter to pre-MemoryBank MIPS150 interface

module MemMIPS150 #(
    parameter CPU_FREQ = 50_000_000,
    parameter COLT45_SCOPE=0, COLT45_BRK=0, COLT45_SCRATCH=0, COLT45_PC=0,
                COLT45_REGREAD=0, COLT45_MEMWRITE=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
)(
    input   clk,
    input   rst,
// Serial (UART):
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,
// Memory Caches:
    output [ 31:0]  dcache_addr,
    output [ 31:0]  icache_addr,
    output [  3:0]  dcache_we,
    output [  3:0]  icache_we,
    output          dcache_re,
    output          icache_re,
    output [ 31:0]  dcache_din,
    output [ 31:0]  icache_din,
    input  [ 31:0]  dcache_dout,
    input  [ 31:0]  icache_dout,
    input           stall,
// Graphics:
    input  [ 31:0]  graphics_status,
    output          pf_valid,
    output [ 31:0]  pf_frame,
    input           frame_interrupt,
    output          gp_valid,
    output [ 31:0]  gp_frame,
    output [ 31:0]  gp_code,
    input           gp_interrupt,
// Chipscope cross-module tap:
input [31:0] DBG_MEM150
);

// Memory/IO "busses" (snagged from MIPS150)
    wire  [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire  [31: 0] IMEM_DATA, DMEM_DATA;
    wire  [31: 0] _WDataMasked;
    wire  [ 3: 0] _WriteMask;
    wire  MemToRegDX_, MemWriteDX_, PCinBIOSDX_;
    wire  [31: 0] MemAddr_MW;
    wire  [31: 0] CNT_Cycle, CNT_Inst;
    wire  CNT_Reset_MW2F_;
    wire  uart0_irq, uart1_irq;

    // Memory Bank & Memory Mapped I/O
    MemBank #(
        .CPU_FREQ(CPU_FREQ),
        .COLT45_SCRATCH(COLT45_SCRATCH),
        .COLT45_MEMWRITE(COLT45_MEMWRITE)
    ) mem_bank (
        .clk(clk),
        .rst(rst),
        .stall(stall),
    // Memory/IO <==> MIPS150
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_), .MemAddr_MW(MemAddr_MW),
        .CNT_Cycle(CNT_Cycle), .CNT_Inst(CNT_Inst),
        .CNT_Reset_MW2F_(CNT_Reset_MW2F_),
    // Interrupts
        .uart0_irq(uart0_irq),
        .uart1_irq(uart1_irq),
    // Serial (UART):
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    // Memory Caches:
        .dcache_addr (dcache_addr),
        .icache_addr (icache_addr),
        .dcache_we   (dcache_we  ),
        .icache_we   (icache_we  ),
        .dcache_re   (dcache_re  ),
        .icache_re   (icache_re  ),
        .dcache_din  (dcache_din ),
        .icache_din  (icache_din ),
        .dcache_dout (dcache_dout),
        .icache_dout (icache_dout),
    // Graphics:
        .graphics_status(graphics_status),
        .pf_valid       (pf_valid),
        .pf_frame       (pf_frame),
        .gp_valid       (gp_valid),
        .gp_frame       (gp_frame),
        .gp_code        (gp_code)
    );

    // MIPS 150 CPU
    MIPS150 #(
        .COLT45_SCOPE(COLT45_SCOPE),
        .COLT45_BRK(COLT45_BRK),
        .COLT45_PC(COLT45_PC),
        .COLT45_REGREAD(COLT45_REGREAD),
        .COLT45_CONTROL(COLT45_CONTROL),
        .COLT45_STEPMAX(COLT45_STEPMAX)
    ) CPU (
        .clk(clk),
        .rst(rst),
        .stall(stall),
    // Memory/IO <==> MemBank
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_), .MemAddr_MW(MemAddr_MW),
        .CNT_Cycle(CNT_Cycle), .CNT_Inst(CNT_Inst),
        .CNT_Reset_MW2F_(CNT_Reset_MW2F_),
    // Interrupts
        .frame_interrupt(frame_interrupt),
        .gp_interrupt(gp_interrupt),
        .uart0_irq(uart0_irq),
        .uart1_irq(uart1_irq)
    );

endmodule
