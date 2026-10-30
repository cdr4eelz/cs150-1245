// PixelFeeder_check_tb: self-checking test of gpu/PixelFeeder.v (COLT45_TESTPAT=0, the DDR path)
// with its CoreGen pixel_fifo (128-bit write @cpu_clk, 32-bit read @dvi_clk).
//
// Memory side (cpu_clk): a model of the RequestController/MIG read path. raf_full is low only
// while PixelFeeder asserts raf_wren and the model "grants" it (random, +grant_pct) and has
// room (+qdepth requests in flight), like RequestController's pixf_raf_full. Each accepted
// request returns two 128-bit rdf beats in order after a random latency (+lat_min..+lat_max
// cycles), with random gaps between beats (+beat_pct), and optional long memory stalls
// (+stall_every/+stall_len cycles: no grants, no responses) to mimic CPU/GPU traffic and DDR
// refresh. The data is a known function of the byte address (frame bits, row, column and a
// check field), in the LITTLEWORDIAN=1 order Memory150 uses (beat 1 = pixels 0..3 of the
// 8-pixel chunk, pixel 0 in bits 127:96).
//
// Checks:
//  - request addresses: 256-bit aligned, rows 0..599 x columns 0..799 in raster order, 8 pixels
//    per request, frame wrap to the frame selected with pf_vframe/pf_wframe (both the address
//    and the frame# form of `FRAME_BITS), first frame = frame bits 0 (reset value)
//  - irq_frame: one 1-cycle pulse per fetched-frame wrap, within 3 cycles of the wrap
//  - pf_status[13:8] follows the fetched frame bits; pf_status[15] (fault) and [14]
//    (!video_active) stay 0
//  - rdf_rden is high whenever the model delivers a beat (PixelFeeder cannot push back)
//  - video side: PixelFeeder shows its startup frame, then switches to the FIFO at the next
//    frame boundary; from then on every pixel the consumer takes (video_ready && video_valid)
//    must equal the memory pattern for (column, row) of the frame fetched for that displayed
//    frame, for +frames displayed frames plus +tail_rows rows of the next (frame wrap); the
//    pixel_fifo never under- or overflows; video_valid is high whenever video_ready is
//  - +fifo_lat=1 expects every displayed pixel one position late (pixel n shows memory pixel
//    n-1, the first one the FIFO's reset value 0): the known PixelFeeder bug, see
//    tests/pixel_feeder_fwft.mk; the other pixel_feeder* tests use it so they check the rest
//  - CONSUMER=0 (default): the consumer is the real base_vid/DVIData with the board's VESA
//    800x600@60 timing (1040x666 total, as in ml505top.v): video_ready exactly in the 800x600
//    active area, DVI_DE/DVI_H/DVI_V one clock later (H pulse x 856..975, V pulse lines
//    637..642) and the DDR pixel bus DVI_D ({R,G[7:4]} after the rising edge, {G[3:0],B}
//    after the falling edge) carrying the pixel taken (needs `define MACROSAFE: base_util's
//    CountRegion otherwise mis-sizes its regions unless MODELSIM is defined)
//  - CONSUMER=1: a behavioral sink with random video_ready (+ready_pct; back-pressure on the
//    FIFO read side, which the real DVI never applies)
// Prints PASS / FAIL.
`timescale 1ns/1ps
module PixelFeeder_check_tb;
`ifndef CONSUMER
  `define CONSUMER 0
`endif
    localparam W = 800, H = 600;
    // DVI timing (ml505top.v: VESA 800x600@60Hz at 40 MHz)
    localparam TW = 1040, FH = 56, PH = 120, BH = 64, TH = 666, FV = 37, PV = 6, BV = 23;

    integer cpu_ps = 20000, dvi_ps = 25000;          // 50 MHz CPU, 40 MHz DVI (ml505top.v)
    integer seed = 1, grant_pct = 50, qdepth = 16, lat_min = 8, lat_max = 64, beat_pct = 80;
    integer stall_every = 0, stall_len = 0, ready_pct = 75, nframes = 2, tail_rows = 0, fifo_lat = 0;
    integer errors = 0;
    integer dx = 0, dy = 0, dframe = 0, first_run = -1, taken = 0, checked = 0, not_valid = 0;

    reg cpu_clk = 0, dvi_clk = 0, cpu_rst = 1, dvi_rst = 1;
    initial begin
        if ($value$plusargs("cpu_ps=%d", cpu_ps)) ;
        #1; forever #(cpu_ps / 2000.0) cpu_clk = ~cpu_clk;
    end
    initial begin
        if ($value$plusargs("dvi_ps=%d", dvi_ps)) ;
        #3; forever #(dvi_ps / 2000.0) dvi_clk = ~dvi_clk;
    end

    task err(input [8*200-1:0] msg); begin
        errors = errors + 1;
        if (errors <= 20) $display("FAIL: %0s (t=%0t)", msg, $time);
    end endtask

    // ---- DUT ----------------------------------------------------------------------------
    wire         raf_full, raf_wren, rdf_rden, video_valid, video_ready, irq_frame;
    wire [ 30:0] raf_addr;
    wire [ 31:0] video;
    wire [ 15:0] pf_status;
    reg          rdf_wren = 0;
    reg  [127:0] rdf_data = 128'bx;
    reg          pf_vframe = 0;
    reg  [ 31:0] pf_wframe = 0;

    PixelFeeder DUT (
        .cpu_clk_g(cpu_clk), .cpu_rst_g(cpu_rst), .dvi_clk_g(dvi_clk), .dvi_rst_g(dvi_rst),
        .raf_full(raf_full), .raf_wren(raf_wren), .raf_addr(raf_addr),
        .rdf_rden(rdf_rden), .rdf_wren(rdf_wren), .rdf_data(rdf_data),
        .video_ready(video_ready), .video_valid(video_valid), .video(video),
        .pf_vframe(pf_vframe), .pf_wframe(pf_wframe), .pf_status(pf_status), .irq_frame(irq_frame));

    // ---- known memory contents ----------------------------------------------------------
    // pixel at DDR byte address {4'h1, b[27:0]}: {frame bits, row, column, check}
    function [31:0] pat(input [27:0] b);
        reg [5:0] f; reg [9:0] y, x;
    begin
        f = b[27:22]; y = b[21:12]; x = b[11:2];
        pat = {f, y, x, x[5:0] ^ {y[2:0], y[5:3]} ^ f ^ 6'h2A};
    end endfunction
    function [31:0] pix(input [5:0] f, input [9:0] x, input [9:0] y);
        pix = pat({f, y, x, 2'b00});
    endfunction

    // ---- memory side (cpu_clk) ----------------------------------------------------------
    localparam QMAX = 64;
    reg  [30:0] q_addr [0:QMAX-1];
    reg  [63:0] q_due  [0:QMAX-1];
    integer q_wr = 0, q_rd = 0, q_n = 0, beat = 0;
    reg  [63:0] cyc = 0;
    reg  grant = 0, stall = 0;
    assign raf_full = !(raf_wren && grant && (q_n < qdepth));   // full unless selected (RequestController)

    // expected request stream
    integer rq_k = 0;                 // request index within the frame being fetched
    integer nfetch = 0;               // fetched frames started
    reg [5:0] fseq [0:63];            // frame bits of each fetched frame
    reg [5:0] m_frame_next = 0, fb_now = 0, fb_prev = 0;
    integer wraps = 0, irqs = 0, nreq = 0, nbeat = 0, max_q = 0, max_pend = 0, min_pend = 1 << 20;
    reg [63:0] wrap_cyc = 0;
    reg irq_d = 0, irq_owed = 0;
    integer overflows = 0;
    reg [8*200-1:0] m;

    initial fseq[0] = 0;
    always @(negedge cpu_clk) begin
        if (stall_every > 0) stall <= ((cyc % stall_every) >= (stall_every - stall_len));
        grant <= !stall && (($random(seed) & 32'h7fffffff) % 100) < grant_pct;
        if (!cpu_rst && q_n > 0 && q_due[q_rd] <= cyc && !stall && (($random(seed) & 32'h7fffffff) % 100) < beat_pct) begin
            rdf_wren <= 1;
            rdf_data <= beat ? {pat({q_addr[q_rd][24:0], 3'b000} + 16), pat({q_addr[q_rd][24:0], 3'b000} + 20),
                                pat({q_addr[q_rd][24:0], 3'b000} + 24), pat({q_addr[q_rd][24:0], 3'b000} + 28)}
                             : {pat({q_addr[q_rd][24:0], 3'b000} +  0), pat({q_addr[q_rd][24:0], 3'b000} +  4),
                                pat({q_addr[q_rd][24:0], 3'b000} +  8), pat({q_addr[q_rd][24:0], 3'b000} + 12)};
        end else begin
            rdf_wren <= 0; rdf_data <= 128'bx;
        end
    end

    reg [30:0] exp_addr;
    reg [9:0] rx, ry;
    always @(posedge cpu_clk) if (!cpu_rst) begin
        cyc = cyc + 1;
        // pf_status[13:8] = framebits one cycle late
        if (pf_status[13:8] !== fb_prev) begin
            $sformat(m, "pf_status[13:8]=%0d, expected frame bits %0d", pf_status[13:8], fb_prev); err(m);
        end
        fb_prev = fb_now;
        if (DUT.PIXFO_DDREAD.pend > max_pend) max_pend = DUT.PIXFO_DDREAD.pend;
        if (first_run >= 0 && DUT.PIXFO_DDREAD.pend < min_pend) min_pend = DUT.PIXFO_DDREAD.pend;
        // irq_frame: one 1-cycle pulse per wrap
        if (irq_frame) begin
            irqs = irqs + 1;
            if (irq_d) err("irq_frame high for more than one cycle");
            else if (!irq_owed || cyc - wrap_cyc > 3) err("irq_frame without a frame wrap in the last 3 cycles");
            irq_owed = 0;
        end else if (irq_owed && cyc - wrap_cyc > 3) begin
            err("no irq_frame within 3 cycles of a frame wrap"); irq_owed = 0;
        end
        irq_d = irq_frame;
        // requests
        if (raf_wren && !raf_full) begin
            rx = (rq_k % (W / 8)) * 8; ry = rq_k / (W / 8);
            exp_addr = {6'd0, fseq[nfetch], ry, rx, 2'b00} >> 3;
            if (raf_addr !== exp_addr) begin
                $sformat(m, "request %0d of fetched frame %0d: raf_addr %h, expected %h (frame %0d row %0d col %0d)",
                         rq_k, nfetch, raf_addr, exp_addr, fseq[nfetch], ry, rx); err(m);
            end
            q_addr[q_wr] = raf_addr;
            q_due[q_wr] = cyc + lat_min + (($random(seed) & 32'h7fffffff) % (lat_max - lat_min + 1));
            q_wr = (q_wr + 1) % QMAX; q_n = q_n + 1; nreq = nreq + 1;
            if (q_n > max_q) max_q = q_n;
            rq_k = rq_k + 1;
            if (rq_k == (W / 8) * H) begin           // last request of the frame: wrap
                rq_k = 0; nfetch = nfetch + 1; fseq[nfetch % 64] = m_frame_next; fb_now = m_frame_next;
                wraps = wraps + 1; wrap_cyc = cyc;
                if (irq_owed) err("frame wrap while the previous irq_frame is still owed");
                irq_owed = 1;
            end
        end
        // responses
        if (rdf_wren) begin
            if (rdf_rden !== 1'b1) err("rdf_rden low while the memory delivers a beat");
            nbeat = nbeat + 1;
            if (beat) begin q_rd = (q_rd + 1) % QMAX; q_n = q_n - 1; end
            beat = !beat;
        end
        // frame select (after the wrap logic: the DUT latches frame_next with a nonblocking assign)
        if (pf_vframe) m_frame_next = (|pf_wframe[31:28]) ? pf_wframe[27:22] : pf_wframe[5:0];
        if (DUT.feeder_wren && DUT.feeder_full) overflows = overflows + 1;
    end

    // ---- video consumer -----------------------------------------------------------------
    generate if (`CONSUMER == 0) begin: dvi_sink
        wire [11:0] DVI_D;
        wire DVI_DE, DVI_H, DVI_V, DVI_RESET_B, DVI_XCLK_N, DVI_XCLK_P;
        DVIData #(.Width(TW), .FrontH(FH), .PulseH(PH), .BackH(BH),
                  .Height(TH), .FrontV(FV), .PulseV(PV), .BackV(BV)) dvi (
            .Clock(dvi_clk), .Reset(dvi_rst),
            .DVI_D(DVI_D), .DVI_DE(DVI_DE), .DVI_H(DVI_H), .DVI_V(DVI_V), .DVI_RESET_B(DVI_RESET_B),
            .DVI_XCLK_N(DVI_XCLK_N), .DVI_XCLK_P(DVI_XCLK_P),
            .Video(video[23:0]), .VideoReady(video_ready), .VideoValid(video_valid));
    end else begin: rand_sink
        reg r = 0;
        always @(negedge dvi_clk) r <= !dvi_rst && (($random(seed) & 32'h7fffffff) % 100) < ready_pct;
        assign video_ready = r;
    end endgenerate

    // DVI sync/blank timing (CONSUMER=0): DVIData's PixelCounter starts at (0,0) on the first
    // clock with VideoValid and counts every clock after that; ready (= PixelActive) must be
    // high exactly for x < 800, y < 600 of the 1040x666 raster, and the registered outputs
    // DVI_DE / DVI_H / DVI_V one clock later must be active / x in [856,976) / y in [637,643).
    // DVI_D carries {R, G[7:4]} after the rising edge and {G[3:0], B} after the falling edge
    // of the pixel registered with DE.
    reg [63:0] dcyc = 0;
    integer k = -1, timing_bad = 0, dvi_d_bad = 0, last_lo_zero = 0, frames_timed = 0, de_clocks = 0, h_clocks = 0, v_clocks = 0;
    reg exp_act = 0, exp_h = 0, exp_v = 0, act_d = 0, h_d = 0, v_d = 0, have_d = 0;
    reg [23:0] pix_d = 0, dvi_hi = 0, dvi_lo = 0;
    integer kx, ky;
    generate if (`CONSUMER == 0) begin: dvi_check
        wire de = dvi_sink.DVI_DE, hs = dvi_sink.DVI_H, vs = dvi_sink.DVI_V;
        always @(posedge dvi_clk) #1 dvi_hi = dvi_sink.DVI_D;   // ODDR rising-edge half
        always @(negedge dvi_clk) #1 dvi_lo = dvi_sink.DVI_D;   // falling-edge half
        always @(posedge dvi_clk) if (!dvi_rst) begin
            dcyc = dcyc + 1;
            if (k < 0 && video_valid) k = 0;
            // registered outputs show the previous clock's raster position
            if (have_d) begin
                if (de !== act_d || hs !== h_d || vs !== v_d) begin
                    timing_bad = timing_bad + 1;
                    if (timing_bad <= 5) begin
                        $sformat(m, "DVI_DE/H/V = %b%b%b at raster (%0d,%0d), expected %b%b%b",
                                 de, hs, vs, (k - 1) % TW, ((k - 1) / TW) % TH, act_d, h_d, v_d); err(m);
                    end
                end
                if (act_d && (k - 1) % TW == W - 1 && dvi_hi[11:0] === pix_d[23:12] && dvi_lo[11:0] === 12'h000
                    && pix_d[11:0] !== 12'h000)
                    last_lo_zero = last_lo_zero + 1;    // DVIData quirk, see the report
                else if (act_d && (dvi_hi[11:0] !== pix_d[23:12] || dvi_lo[11:0] !== pix_d[11:0])) begin
                    dvi_d_bad = dvi_d_bad + 1;
                    if (dvi_d_bad <= 5) begin
                        $sformat(m, "DVI_D = %h/%h at raster (%0d,%0d), expected %h/%h",
                                 dvi_hi[11:0], dvi_lo[11:0], (k - 1) % TW, ((k - 1) / TW) % TH, pix_d[23:12], pix_d[11:0]); err(m);
                    end
                end
                de_clocks = de_clocks + de; h_clocks = h_clocks + hs; v_clocks = v_clocks + vs;
            end
            if (k >= 0) begin
                kx = k % TW; ky = (k / TW) % TH;
                exp_act = (kx < W) && (ky < H);
                exp_h = (kx >= W + FH) && (kx < W + FH + PH);
                exp_v = (ky >= H + FV) && (ky < H + FV + PV);
                if (video_ready !== exp_act) begin
                    timing_bad = timing_bad + 1;
                    if (timing_bad <= 5) begin
                        $sformat(m, "video_ready = %b at raster (%0d,%0d), expected %b", video_ready, kx, ky, exp_act); err(m);
                    end
                end
                if (kx == TW - 1 && ky == TH - 1) frames_timed = frames_timed + 1;
                act_d = exp_act; h_d = exp_h; v_d = exp_v; pix_d = video[23:0]; have_d = 1;
                k = k + 1;
            end
        end
    end endgenerate

    // pixel stream
    integer bad_pix = 0, empty_reads = 0;
    reg [31:0] exp_pix, exp_tmp, prev_exp = 32'h0;   // prev_exp: pixel_fifo dout reset value
    reg [5:0] f_exp;
    always @(posedge dvi_clk) if (!dvi_rst) begin
        if (video_ready && !video_valid && taken > 0) not_valid = not_valid + 1;
        if (video_ready && DUT.isRunning && DUT.feeder_empty) empty_reads = empty_reads + 1;
        if (video_ready && video_valid) begin
            if (dx == 0 && dy == 0) begin
                $display("displayed frame %0d starts (t=%0t)", dframe, $time);
                if (DUT.isRunning && first_run < 0) begin
                    first_run = dframe;
                    $display("displayed frame %0d: first FIFO-fed frame (t=%0t)", dframe, $time);
                end
                if (first_run < 0 && dframe >= 3) begin err("PixelFeeder still not running after 3 frames"); $finish; end
                if (first_run >= 0 && dframe - first_run == nframes && tail_rows == 0) begin
                    report; $finish;
                end
            end
            if (first_run >= 0 && !DUT.isRunning) err("isRunning dropped");
            if (first_run < 0 && DUT.isRunning) err("isRunning rose mid-frame");
            if (first_run >= 0) begin
                f_exp = fseq[(dframe - first_run) % 64];
                exp_pix = pix(f_exp, dx, dy);
                if (fifo_lat) begin   // compensate the known 1-pixel lag (see tests/pixel_feeder*.mk)
                    exp_tmp = exp_pix; exp_pix = prev_exp; prev_exp = exp_tmp;
                end
                checked = checked + 1;
                if (video !== exp_pix) begin
                    bad_pix = bad_pix + 1;
                    if (bad_pix <= 10) $display("FAIL: displayed frame %0d (fetched frame %0d, bits %0d) pixel (%0d,%0d): %h, expected %h",
                                                dframe, dframe - first_run, f_exp, dx, dy, video, exp_pix);
                end
            end
            taken = taken + 1;
            if (dx == W - 1) begin
                dx = 0;
                if (first_run >= 0 && dframe - first_run == nframes && dy + 1 == tail_rows) begin
                    report; $finish;
                end
                if (dy == H - 1) begin dy = 0; dframe = dframe + 1; end
                else dy = dy + 1;
            end else dx = dx + 1;
        end
    end

    task report; begin
        $display("%0d pixels taken, %0d checked over %0d displayed frames + %0d rows; %0d requests, %0d beats, %0d fetched-frame wraps, %0d irq_frame",
                 taken, checked, nframes, tail_rows, nreq, nbeat, wraps, irqs);
        $display("max requests in flight %0d (of %0d); PixelFeeder pend (requests not yet shown, 8 pixels each) max %0d, min %0d while displaying; consumer %0d",
                 max_q, qdepth, max_pend, min_pend, `CONSUMER);
        if (`CONSUMER == 0) $display("DVI: %0d whole 1040x666 frames, DE/H/V high for %0d/%0d/%0d clocks, %0d timing and %0d DVI_D mismatches",
                                     frames_timed, de_clocks, h_clocks, v_clocks, timing_bad, dvi_d_bad);
        if (bad_pix) begin $sformat(m, "%0d displayed pixels differ from memory", bad_pix); err(m); end
        if (not_valid) begin $sformat(m, "video_valid low on %0d cycles with video_ready high", not_valid); err(m); end
        if (overflows) begin $sformat(m, "pixel_fifo written while full on %0d cycles (overflow)", overflows); err(m); end
        if (empty_reads) begin $sformat(m, "pixel_fifo read while empty on %0d cycles (underflow)", empty_reads); err(m); end
        if (pf_status[15]) err("pf_status[15] (video fault) set");
        if (pf_status[14]) err("pf_status[14] (!video_active) set while displaying");
        if (`CONSUMER == 0 && frames_timed < 1) err("no complete DVI frame timed");
        if (last_lo_zero) $display("NOTE: DVI_D falling-edge half {G[3:0],B} of the last pixel of a line (x=%0d) was 0 on %0d lines: DVIData resets its ODDRs with the unregistered ~PixelActive, which the ODDR model also applies on the falling edge, while DVI_DE is registered (DVIData, not PixelFeeder; not counted as an error)", W - 1, last_lo_zero);
        if (timing_bad) begin $sformat(m, "%0d DVI timing mismatches", timing_bad); err(m); end
        if (dvi_d_bad) begin $sformat(m, "%0d DVI_D mismatches", dvi_d_bad); err(m); end
`ifdef FORCE_FAIL
        errors = errors + 1;
`endif
        if (errors == 0) $display("PASS: PixelFeeder");
        else $display("FAIL: PixelFeeder, %0d errors", errors);
    end endtask

    // ---- stimulus -----------------------------------------------------------------------
    initial begin
        if ($value$plusargs("seed=%d", seed)) ;
        if ($value$plusargs("grant_pct=%d", grant_pct)) ;
        if ($value$plusargs("qdepth=%d", qdepth)) ;
        if ($value$plusargs("lat_min=%d", lat_min)) ;
        if ($value$plusargs("lat_max=%d", lat_max)) ;
        if ($value$plusargs("beat_pct=%d", beat_pct)) ;
        if ($value$plusargs("stall_every=%d", stall_every)) ;
        if ($value$plusargs("stall_len=%d", stall_len)) ;
        if ($value$plusargs("ready_pct=%d", ready_pct)) ;
        if ($value$plusargs("frames=%d", nframes)) ;
        if ($value$plusargs("tail_rows=%d", tail_rows)) ;
        if ($value$plusargs("fifo_lat=%d", fifo_lat)) ;
        if (qdepth > QMAX) qdepth = QMAX;
        $display("PixelFeeder_check_tb: consumer %0d, cpu %0d ps, dvi %0d ps, seed %0d, grant %0d%%, qdepth %0d, latency %0d..%0d, beat %0d%%, stall %0d/%0d, ready %0d%%, %0d frames + %0d rows, fifo_lat %0d",
                 `CONSUMER, cpu_ps, dvi_ps, seed, grant_pct, qdepth, lat_min, lat_max, beat_pct, stall_len, stall_every, ready_pct, nframes, tail_rows, fifo_lat);
        if ($test$plusargs("vcd")) begin $dumpfile("PixelFeeder_check_tb.vcd"); $dumpvars(0, PixelFeeder_check_tb); end
        repeat (20) @(posedge dvi_clk);
        repeat (2) @(negedge cpu_clk);
        cpu_rst = 0;
        @(negedge dvi_clk); dvi_rst = 0;
        // frame selects, each taken at the next fetch wrap: address form 0x1240_0000 (frame
        // bits 9) during the first fetched frame, frame# 5 during the second, frame# 3 early in
        // the third
        wait (nfetch == 0 && rq_k == 20000); @(negedge cpu_clk); pf_wframe = 32'h1240_0000; pf_vframe = 1;
        @(negedge cpu_clk); pf_vframe = 0; pf_wframe = 32'hx;
        wait (nfetch == 1 && rq_k == 30000); @(negedge cpu_clk); pf_wframe = 32'd5; pf_vframe = 1;
        @(negedge cpu_clk); pf_vframe = 0; pf_wframe = 32'hx;
        wait (nfetch == 2 && rq_k == 100); @(negedge cpu_clk); pf_wframe = 32'd3; pf_vframe = 1;
        @(negedge cpu_clk); pf_vframe = 0; pf_wframe = 32'hx;
    end
endmodule
