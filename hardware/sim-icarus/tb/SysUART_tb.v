// SysUART_tb: whole MIPS150 (CPU + BIOS/ISR/IMEM/DMEM block RAMs + MemMapIO + UART), no DDR,
// driven over its serial port. Runs a real program from ../../software (built by the Makefile
// into build/_sw and loaded through the CoreGen BRAMs' .mif init files) and compares
// everything it sends on the UART with a golden transcript.
//
//   +in=<file>      text sent to the CPU, one line at a time ('\n' is sent as '\r')
//   +golden=<file>  expected UART output, byte for byte; '~' matches any byte (cycle counts, PRNG)
//   +prompt=<str>   if set, wait until the output ends with this before sending each line
//   +prompt_lines=<n> only wait for the prompt before the first n lines (e.g. after 'jal' to a
//                   program that has no prompt); default: all lines
//   +out=<file>     where to write the captured output (default uart_out.txt)
//   +max_cycles=<n> give up after n clocks (default 3,000,000)
//   +gap=<n>        clocks between input bytes (default 3 character times)
//   +ddr=<file>     $readmemh image for the behavioral cache-side memory (see below)
//
// The UART baud divider is ClockFreq/BaudRate, so CPU_FREQ = 16 * 115200 makes one serial bit
// 16 clocks (the real board uses 50 MHz = 434 clocks/bit); timing-wise nothing else changes.
// Stops when all input has been sent and either the output is as long as the golden
// transcript or the line has been idle for IDLE_CYCLES. Prints PASS / FAIL.
`timescale 1ns/1ps
module SysUART_tb;
    localparam BAUD = 115_200;
    localparam CPU_FREQ = 16 * BAUD;
    localparam IDLE_CYCLES = 20 * 10 * 16 * 4;   // ~80 character times
`ifdef SYS_PC_BOOT
    localparam PC_BOOT = `SYS_PC_BOOT;
`else
    localparam PC_BOOT = 32'h4000_0000;     // BIOS
`endif

    reg clk = 0, rst = 1;
    always #10 clk = ~clk;

    wire cpu_rx, cpu_tx;   // from the CPU's point of view

    // Behavioral stand-in for Memory150 (caches + DDR) at 0x0xxxxxxx-0x3xxxxxxx: one shared
    // 1 MB array (addresses alias modulo 1 MB), synchronous read like the cache BRAMs, no stalls.
    // The BIOS keeps its stack there (_sp = 0x1F000000). +ddr=<file> preloads it ($readmemh
    // words, '@' addresses are word indexes).
    wire [31:0] dcache_addr, icache_addr, dcache_din, icache_din;
    wire [ 3:0] dcache_we, icache_we;
    wire        dcache_re, icache_re;
    reg  [31:0] dcache_dout, icache_dout;
    reg  [31:0] ddr [0:262143];
    integer di;
    always @(posedge clk) begin
        for (di = 0; di < 4; di = di + 1) begin
            if (dcache_we[di]) ddr[dcache_addr[19:2]][8*di +: 8] <= dcache_din[8*di +: 8];
            if (icache_we[di]) ddr[icache_addr[19:2]][8*di +: 8] <= icache_din[8*di +: 8];
        end
        if (dcache_re) dcache_dout <= ddr[dcache_addr[19:2]];
        if (icache_re) icache_dout <= ddr[icache_addr[19:2]];
    end
    MIPS150 #(.CPU_FREQ(CPU_FREQ), .PC_BOOT(PC_BOOT)) DUT (
        .clk(clk), .rst(rst), .stall(1'b0),
        .FPGA_SERIAL_RX(cpu_rx), .FPGA_SERIAL_TX(cpu_tx),
        .dcache_addr(dcache_addr), .icache_addr(icache_addr), .dcache_we(dcache_we), .icache_we(icache_we),
        .dcache_re(dcache_re), .icache_re(icache_re), .dcache_din(dcache_din), .icache_din(icache_din),
        .dcache_dout(dcache_dout), .icache_dout(icache_dout),
        .pf_vframe(), .gp_vcode(), .gp_vframe(), .pf_wframe(), .gp_wcode(), .gp_wframe(),
        .gp_rcode(32'b0), .pf_status(16'b0), .gp_status(16'b0),
        .irq_pf_frame(1'b0), .irq_gp_done(1'b0));

    // Testbench side of the serial line: the course UART at the same clock/baud.
    reg  [7:0] tx_data = 0;
    reg        tx_valid = 0;
    wire       tx_ready;
    wire [7:0] rx_data;
    wire       rx_valid;
    UART #(.ClockFreq(CPU_FREQ), .BaudRate(BAUD)) host (
        .Clock(clk), .Reset(rst),
        .DataIn(tx_data), .DataInValid(tx_valid), .DataInReady(tx_ready),
        .DataOut(rx_data), .DataOutValid(rx_valid), .DataOutReady(1'b1),
        .SIn(cpu_tx), .SOut(cpu_rx));

    // ---- captured output ----
    reg [7:0] outbuf [0:65535];
    integer   nout = 0, idle = 0, cycles = 0;
    reg [8*200-1:0] line = 0;
    integer   linelen = 0;
    always @(posedge clk) begin
        cycles = cycles + 1;
        idle = idle + 1;
        if (!rst && rx_valid) begin
            outbuf[nout] = rx_data;
            nout = nout + 1;
            idle = 0;
            if (rx_data == 8'h0a) begin
                $display("UART< %0s", line);
                line = 0; linelen = 0;
            end else if (rx_data != 8'h0d && linelen < 199) begin
                line = {line[8*199-1:0], rx_data};
                linelen = linelen + 1;
            end
        end
    end

    // ---- golden ----
    reg [7:0] gold [0:65535];
    integer   ngold = 0;
    reg [8*256-1:0] fname, prompt;
    integer   plen = 0;
    integer   prompt_lines = 1 << 30, nline = 0, gap = 3 * 10 * 16, fd, c, i, mark, errors = 0, max_cycles = 3_000_000;

    function prompt_seen;
        input dummy;
        integer j;
        begin
            prompt_seen = (nout >= plen);
            for (j = 0; j < plen && prompt_seen; j = j + 1)
                if (outbuf[nout - plen + j] !== prompt[8*(plen-1-j) +: 8]) prompt_seen = 0;
        end
    endfunction

    task send_byte(input [7:0] b);
    begin
        @(negedge clk);
        while (!tx_ready) @(negedge clk);
        tx_data = b; tx_valid = 1;
        @(negedge clk);
        tx_valid = 0;
        // gap after each byte: the BIOS echoes every character and the UARTs have no FIFO, so
        // back-to-back input (one character time apart) loses characters
        repeat (gap) @(negedge clk);
    end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin $dumpfile("SysUART_tb.vcd"); $dumpvars(0, SysUART_tb); end
        // golden
        for (di = 0; di < 262144; di = di + 1) ddr[di] = 0;
        if ($value$plusargs("ddr=%s", fname)) $readmemh(fname, ddr);
        if (!$value$plusargs("golden=%s", fname)) begin $display("FAIL: no +golden="); $finish; end
        fd = $fopen(fname, "rb");
        if (fd == 0) begin $display("FAIL: cannot open golden %0s", fname); $finish; end
        c = $fgetc(fd);
        while (c >= 0) begin gold[ngold] = c; ngold = ngold + 1; c = $fgetc(fd); end
        $fclose(fd);
        if (!$value$plusargs("prompt=%s", prompt)) prompt = 0;
        plen = 0;
        for (i = 0; i < 256; i = i + 1) if (prompt[8*i +: 8] != 0) plen = i + 1;
        if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 3_000_000;
        if (!$value$plusargs("gap=%d", gap)) gap = 3 * 10 * 16;
        if (!$value$plusargs("prompt_lines=%d", prompt_lines)) prompt_lines = 1 << 30;

        repeat (20) @(posedge clk);
        rst = 0;

        // input script
        fd = 0;
        if ($value$plusargs("in=%s", fname)) begin
            fd = $fopen(fname, "rb");
            if (fd == 0) begin $display("FAIL: cannot open input %0s", fname); $finish; end
        end
        if (fd != 0) begin
            c = $fgetc(fd);
            mark = -1;
            while (c >= 0) begin
                // wait for a prompt that arrived after the previous line was sent
                if (plen > 0 && nline < prompt_lines) wait ((nout > mark && prompt_seen(0)) || cycles > max_cycles);
                nline = nline + 1;
                if (cycles > max_cycles) begin $display("FAIL: timeout waiting for prompt"); finish_up; end
                // send one line
                while (c >= 0 && c != 8'h0a) begin send_byte(c); c = $fgetc(fd); end
                if (c == 8'h0a) begin send_byte(8'h0d); c = $fgetc(fd); end
                mark = nout;
            end
            $fclose(fd);
        end
        wait (nout >= ngold || idle > IDLE_CYCLES || cycles > max_cycles);
        finish_up;
    end

    task finish_up;
        integer k, first;
        reg [8*64-1:0] ctx;
    begin
        if (linelen > 0) $display("UART< %0s", line);
        fd = $fopen("uart_out.txt", "wb");
        for (k = 0; k < nout; k = k + 1) $fwrite(fd, "%c", outbuf[k]);
        $fclose(fd);
        first = -1;
        for (k = 0; k < ngold && k < nout; k = k + 1)
            if (first < 0 && outbuf[k] !== gold[k] && gold[k] != "~") first = k;
        if (first < 0 && nout < ngold) first = nout;
        $display("%0d bytes received (golden %0d), %0d cycles", nout, ngold, cycles);
        if (first >= 0) begin
            $display("FAIL: UART output differs from golden at byte %0d (got %h, want %h); see uart_out.txt",
                     first, first < nout ? outbuf[first] : 8'hxx, gold[first]);
            $finish;
        end
        $display("PASS: UART transcript matches golden");
        $finish;
    end
    endtask
endmodule
