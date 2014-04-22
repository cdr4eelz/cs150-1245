
    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    MIPS150 #(
        .CPU_FREQ(CPU_FREQ),
        .CPU_CORE(CPU_CORE)
    ) DUT (
        .clk(cpu_clk_g), .rst(rst_cpu_cpu), .stall(stall),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX), .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
        .dcache_addr(dcache_addr),  .icache_addr(icache_addr),
        .dcache_we  (dcache_we  ),  .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),  .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),  .icache_din (icache_din ),
        .dcache_dout(dcache_dout),  .icache_dout(icache_dout),
        .pf_vframe(pf_vframe),        .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),        .gp_wcode(gp_wcode), .gp_wframe(gp_wframe),
                                      .gp_rcode(gp_rcode),
        .pf_status(pf_status),                             .gp_status(gp_status),
        .irq_pf_frame(irq_pf_frame),  .irq_gp_done(irq_gp_done)
    );
