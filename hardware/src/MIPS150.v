// Simple adapter to house MemoryBank <=> MIPS150 interface

module MIPS150 #(
    parameter CPU_FREQ = 50_000_000,
    parameter PC_BOOT=32'h4000_0000 //NOTE: h6000_0000 for SCRATCH_IMEM
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
    output          pf_vframe,    gp_vcode, gp_vframe,
    output [ 31:0]  pf_wframe,    gp_wcode, gp_wframe,
    input  [ 31:0]                gp_rcode,
    input  [ 15:0]  pf_status,              gp_status,
    input           irq_pf_frame, irq_gp_done
);

// Memory/IO "buses" (snagged from MIPS150)
    wire  [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire  [31: 0] IMEM_DATA, DMEM_DATA;
    wire          MemToRegDX_, MemWriteDX_, PCinBIOSDX_;
    wire  [31: 0] _WDataMasked;
    wire  [ 3: 0] _WriteMask;
    wire          irq_uart0, irq_uart1;

    // Memory Bank & Memory Mapped I/O
    MemBank #(
        .CPU_FREQ(CPU_FREQ)
    ) membank (
        .clk(clk), .rst(rst), .stall(stall),
    // Memory/IO <==> MIPS150
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked),
        ._WriteMask(_WriteMask),
    // Interrupts
        .irq_uart0(irq_uart0),
        .irq_uart1(irq_uart1),
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
        .pf_vframe(pf_vframe),  .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),  .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                .gp_rcode(gp_rcode),
        .pf_status(pf_status),                       .gp_status(gp_status)
    );

    // MIPS 150 CPU (or alternate)
`ifdef COLT45_CPU
    `COLT45_CPU
`else
    CPUMIPS
`endif
    #(
        .PC_BOOT(PC_BOOT)
    ) cpu (
        .clk(clk), .rst(rst), .stall(stall),
    // Memory/IO <==> MemBank
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask),
    // Interrupts
        .irq_uart0(irq_uart0), .irq_uart1(irq_uart1),
        .irq_pf_frame(irq_pf_frame),
        .irq_gp_done(irq_gp_done)
    );

endmodule
