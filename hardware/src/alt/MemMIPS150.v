// Simple adapter to pre-MemoryBank MIPS150 interface

module MemMIPS150 #(
    parameter CPU_FREQ = 50_000_000,
    parameter COLT45_SCOPE=0, COLT45_BRK=0, COLT45_SCRATCH=0, COLT45_PC=0,
                COLT45_REGREAD=0, COLT45_MEMWRITE=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
)(
    input   clk, rst, stall,

// Serial (UART):
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,

// Memory Caches:
    output [ 31:0]  dcache_addr,    icache_addr,
    output [  3:0]  dcache_we,      icache_we,
    output          dcache_re,      icache_re,
    output [ 31:0]  dcache_din,     icache_din,
    input  [ 31:0]  dcache_dout,    icache_dout,

// GPU control:
    input  [ 15:0]  pf_status,  gp_status,
    output          pf_valid,   gp_valid,
    output [ 31:0]  pf_frame,   gp_frame,gp_code,
    input           pf_irq,     gp_irq
);

// Memory/IO "buses" (snagged from MIPS150)
    wire  [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire  [31: 0] IMEM_DATA, DMEM_DATA;
    wire          MemToRegDX_, MemWriteDX_, PCinBIOSDX_;
    wire  [31: 0] _WDataMasked;
    wire  [ 3: 0] _WriteMask;
    wire          uart0_irq, uart1_irq;

    // Memory Bank & Memory Mapped I/O
    MemBank #(
        .CPU_FREQ(CPU_FREQ),
        .COLT45_SCRATCH(COLT45_SCRATCH),
        .COLT45_MEMWRITE(COLT45_MEMWRITE)
    ) mem_bank (
        .clk(clk), .rst(rst), .stall(stall),
    // Memory/IO <==> MIPS150
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked),
        ._WriteMask(_WriteMask),
    // Interrupts
        .uart0_irq(uart0_irq),
        .uart1_irq(uart1_irq),
    // Serial (UART):
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    // Memory Caches:
        .dcache_addr (dcache_addr),   .icache_addr (icache_addr),
        .dcache_we   (dcache_we  ),   .icache_we   (icache_we  ),
        .dcache_re   (dcache_re  ),   .icache_re   (icache_re  ),
        .dcache_din  (dcache_din ),   .icache_din  (icache_din ),
        .dcache_dout (dcache_dout),   .icache_dout (icache_dout),
    // GPU control:
        .pf_status(pf_status),  .gp_status(gp_status),
        .pf_valid(pf_valid),    .gp_valid(gp_valid),
        .pf_frame(pf_frame),    .gp_frame(gp_frame),.gp_code(gp_code)
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
        .clk(clk), .rst(rst), .stall(stall),
    // Memory/IO <==> MemBank
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
    // Interrupts
        .pf_irq(pf_irq),
        .gp_irq(gp_irq),
        .uart0_irq(uart0_irq),
        .uart1_irq(uart1_irq)
    );

endmodule
