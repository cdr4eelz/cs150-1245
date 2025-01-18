// Simple adapter to house MemoryBank <=> MIPS150 interface

module MIPS150 #(
    parameter CPU_FREQ = 50_000_000,
    parameter PC_BOOT=32'h4000_0000, //NOTE: h6000_0000 for SCRATCH_IMEM
    parameter CPU_CORE = "" //Defaults to "MIPS" (MIPS.core)
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

    wire irq_uart0, irq_uart1;

    wire [ 4: 0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
    wire [31: 0] REGFILE_rd1, REGFILE_rd2, REGFILE_wd;
    wire REGFILE_we;

    wire            COP0_we;
    wire   [31: 0]  COP0_wd, COP0_rd;
    wire   [ 4: 0]  COP0_ra;
    wire   [31: 0]  intr_pc;
    wire            intr_handled, intr_request;

    RegFile regfile
    ( .clk(clk),
        // Synchronous-Write, "we" is enable
        .wa(REGFILE_wa),    .wd(REGFILE_wd),    .we(REGFILE_we),
        // Asynchronous-Read, always enabled (hold ra1/2 steady during stall!)
        .ra1(REGFILE_ra1),  .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2),  .rd2(REGFILE_rd2)
    );

    COP0150 cop0 (
        .clk(clk), .rst(rst), .ena(1'b1), //NOTE:Individual activities still stall
    // "Register" access <==> CPU-CORE
        .COP0_we(COP0_we),     //IN     (mtc0)
        .COP0_wd(COP0_wd),     //IN-32  (Always fed, only used if enabled)
        .COP0_rd(COP0_rd),     //OUT-32 (Injected into StageDX.RegWValue_)
        .COP0_ra(COP0_ra),     //IN-5   (Cop Register address to read/write)
    // Interrupt Handling <==> CPU-CORE
        .intr_pc     (intr_pc),       //IN-32 (PCNEXT_F_ supersceeded by ISRPC)
        .intr_handled(intr_handled),    //IN  (Acknowledge ISR is happening)
        .intr_request(intr_request),    //OUT (Like branch to fixed address)
    // Interrupt Requests <==> Devices
        .irq_uart0(irq_uart0), .irq_uart1(irq_uart1),
        .irq_pf_frame(irq_pf_frame), .irq_gp_done(irq_gp_done)
    );


    // CPU-CORE <=> MemBank (snagged from MIPS150)
    wire  [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire  [31: 0] IMEM_DATA, DMEM_DATA;
    wire          MemToRegDX_, MemWriteDX_, PCinBIOSDX_;
    wire  [31: 0] _WDataMasked;
    wire  [ 3: 0] _WriteMask;


generate if (CPU_CORE=="ECHODDR") begin:NOMEMS

    assign pf_vframe = 1'b0, gp_vcode = 1'b0, gp_vframe = 1'b0,
            pf_wframe = 32'bx, gp_wcode = 32'bx, gp_wframe = 32'bx;

end else begin:MEMS //"MIPS" & any others wanting MemBank

    // Memory Bank & Memory Mapped I/O
    MemBank #(
        .CPU_FREQ(CPU_FREQ)
    ) bank (
        .clk(clk), .rst(rst), .stall(stall),
    // Memory/IO <==> CPU-CORE
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked),
        ._WriteMask(_WriteMask),
    // Interrupts <==> COP0150
        .irq_uart0(irq_uart0), .irq_uart1(irq_uart1),

    // Serial (UART):
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX), .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    // Memory Caches:
        .dcache_addr(dcache_addr),   .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),   .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),   .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),   .icache_din (icache_din ),
        .dcache_dout(dcache_dout),   .icache_dout(icache_dout),
    // GPU control:
        .pf_vframe(pf_vframe),   .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),   .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                 .gp_rcode(gp_rcode),
        .pf_status(pf_status),                        .gp_status(gp_status)
    );

end endgenerate


// CPU-CORE (MIPS150 or alternate)
generate if (CPU_CORE=="ECHODDR") begin:ECHODDR

    //MemBank & RegFile unused (left to raisin)

    CPUEchoDDR #(
        .CPU_FREQ(CPU_FREQ)
    ) core (
        .clk(clk), .rst(rst), .stall(stall),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX), .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
        .dcache_addr (dcache_addr),   .icache_addr (icache_addr),
        .dcache_we   (dcache_we  ),   .icache_we   (icache_we  ),
        .dcache_re   (dcache_re  ),   .icache_re   (icache_re  ),
        .dcache_din  (dcache_din ),   .icache_din  (icache_din ),
        .dcache_dout (dcache_dout),   .icache_dout (icache_dout)
    );

end else begin:MIPS

    CPUMIPS #(
        .PC_BOOT(PC_BOOT)
    ) core (
        .clk(clk), .rst(rst), .stall(stall),
    // Regfile (async-read, sync-write)
        .REGFILE_we(REGFILE_we),
        .REGFILE_wa(REGFILE_wa),    .REGFILE_wd(REGFILE_wd),
        .REGFILE_ra1(REGFILE_ra1),  .REGFILE_ra2(REGFILE_ra2),
        .REGFILE_rd1(REGFILE_rd1),  .REGFILE_rd2(REGFILE_rd2),
    // COP0 (async-read, sync-write from reg in same-cycle)
        .COP0_we(COP0_we), .COP0_wd(COP0_wd),
        .COP0_rd(COP0_rd), .COP0_ra(COP0_ra),
        .intr_pc     (intr_pc),
        .intr_handled(intr_handled),
        .intr_request(intr_request),
    // Memory/IO <==> MemBank
        .IMEM_ADDR(IMEM_ADDR), .DMEM_ADDR(DMEM_ADDR),
        .IMEM_DATA(IMEM_DATA), .DMEM_DATA(DMEM_DATA),
        .MemToRegDX_(MemToRegDX_), .MemWriteDX_(MemWriteDX_),
        .PCinBIOSDX_(PCinBIOSDX_),
        ._WDataMasked(_WDataMasked), ._WriteMask(_WriteMask)
    );
end //<default> CPUMIPS

endgenerate

endmodule
