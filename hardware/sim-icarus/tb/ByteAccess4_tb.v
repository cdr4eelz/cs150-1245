`timescale 1ns/1ps
// Direct, exhaustive unit test for innerds/ByteAccess4.v (combinational).
// Sweeps every MemShift (0..3), SubIndex (0..3) and IsSigned (0/1) for a set of data
// patterns (sign bits set/clear in every lane, 0x80/0x7F/0xFF/0x8000/0x7FFF, random) and
// compares ByteMask, WordMasked (store data) and ValExtract (load data) with an
// independent behavioral MIPS reference model (byte-lane loop, no shifts/tables).
//
// Conventions (from InstructionControl.v / StageMW.v / ByteAccess4.v):
//   MemShift = ~opcode[1:0]: 3 = byte (lb/lbu/sb), 2 = half (lh/lhu/sh), 0 = word (lw/sw),
//              1 = lwl/lwr/swl/swr pattern (not implemented by the CPU).
//   SubIndex = address[1:0] (byte offset within the word).
//   Big-endian: byte offset 0 is WordFull[31:24]; ByteMask[3] enables WordFull[31:24].
//   IsSigned = 1 for lb/lh (sign-extend), 0 for lbu/lhu (zero-extend); stores and words
//              ignore it.
//   Unsupported/misaligned combos (MemShift 1; half at odd offset; word at offset != 0):
//              the module has no exception output; the expected behavior is the module's
//              documented default: ByteMask 0 (no write), WordMasked 0, ValExtract 0.
// Plusargs: +nrand=<n> random patterns (default 200), +seed=<s>, +vcd=<file>
// -DFORCE_FAIL injects one error.
module ByteAccess4_tb;
  reg  [1:0]  MemShift, SubIndex;
  reg         IsSigned;
  reg  [31:0] WordFull;
  wire [3:0]  ByteMask;
  wire [31:0] WordMasked, ValExtract;

  ByteAccess4 dut(.MemShift(MemShift), .SubIndex(SubIndex), .IsSigned(IsSigned),
                  .WordFull(WordFull), .ByteMask(ByteMask), .WordMasked(WordMasked),
                  .ValExtract(ValExtract));

  // ---- reference model ----
  reg [3:0]  eMask; reg [31:0] eWM, eVE; reg eValid;
  integer n, k, j, lane;
  task ref_model;
    reg [7:0] b; reg [31:0] v;
    begin
      case (MemShift) 2'd3: n = 1; 2'd2: n = 2; 2'd0: n = 4; default: n = 0; endcase
      eValid = (n != 0) && ((SubIndex % n) == 0);
      eMask = 4'b0; eWM = 32'd0; eVE = 32'd0;
      if (eValid) begin
        // store: rt's low n bytes go to offsets SubIndex..SubIndex+n-1, MSB first
        for (j = 0; j < n; j = j + 1) begin
          k = SubIndex + j; lane = 3 - k;           // big-endian lane of offset k
          b = WordFull >> (8*(n-1-j));
          eMask[lane] = 1'b1;
          eWM = eWM | ({24'd0, b} << (8*lane));
        end
        // load: memory bytes at offsets SubIndex.., MSB first, then extend
        v = 32'd0;
        for (j = 0; j < n; j = j + 1) begin
          lane = 3 - (SubIndex + j);
          b = WordFull >> (8*lane);
          v = (v << 8) | b;
        end
        if (IsSigned && n == 1 && v[7])  v = v | 32'hFFFFFF00;
        if (IsSigned && n == 2 && v[15]) v = v | 32'hFFFF0000;
        eVE = v;
      end
    end
  endtask

  function [8*8-1:0] opname(input [1:0] ms, input s);
    case (ms) 2'd3: opname = s ? "lb/sb" : "lbu/sb"; 2'd2: opname = s ? "lh/sh" : "lhu/sh";
              2'd0: opname = "lw/sw"; default: opname = "lwl/r?"; endcase
  endfunction

  // ---- patterns ----
  reg [31:0] pats[0:1023]; integer np, nrand, seed, i, ms, si, sg;
  integer vecs, errs, ebm, ewm, eve, esign, shown;
  reg [8*256-1:0] fn;
  task addp(input [31:0] p); begin pats[np] = p; np = np + 1; end endtask

  initial begin
    if ($value$plusargs("vcd=%s", fn)) begin $dumpfile(fn); $dumpvars(0, ByteAccess4_tb); end
    if (!$value$plusargs("nrand=%d", nrand)) nrand = 200;
    if (!$value$plusargs("seed=%d", seed)) seed = 150;
    np = 0;
    addp(32'h00000000); addp(32'hFFFFFFFF); addp(32'h80808080); addp(32'h7F7F7F7F);
    addp(32'h80000000); addp(32'h7FFFFFFF); addp(32'h12345678); addp(32'hFABCDE83);
    addp(32'h80FF7F01); addp(32'hA5A55A5A); addp(32'h01020304); addp(32'hFEDCBA98);
    for (i = 0; i < 4; i = i + 1) begin          // one marked byte per lane, rest 0 / FF
      addp(32'h80 << (8*i)); addp(32'h7F << (8*i)); addp(32'hFF << (8*i));
      addp(~(32'h80 << (8*i))); addp(~(32'h7F << (8*i)));
    end
    for (i = 0; i < 2; i = i + 1) begin          // halfwords in each half
      addp(32'h8000 << (16*i)); addp(32'h7FFF << (16*i)); addp(32'hFFFF << (16*i));
      addp(32'h80FF << (16*i)); addp(32'h7F00 << (16*i)); addp(32'h0080 << (16*i));
    end
    addp(32'h8000_7FFF); addp(32'h7FFF_8000);
    for (i = 0; i < nrand && np < 1024; i = i + 1) addp($random(seed));

    vecs = 0; errs = 0; ebm = 0; ewm = 0; eve = 0; esign = 0; shown = 0;
    for (i = 0; i < np; i = i + 1)
      for (ms = 0; ms < 4; ms = ms + 1)
        for (si = 0; si < 4; si = si + 1)
          for (sg = 0; sg < 2; sg = sg + 1) begin
            WordFull = pats[i]; MemShift = ms; SubIndex = si; IsSigned = sg;
            #10;
            ref_model;
`ifdef FORCE_FAIL
            if (vecs == 0) eVE = ~eVE;
`endif
            vecs = vecs + 1;
            if (ByteMask !== eMask || WordMasked !== eWM || ValExtract !== eVE) begin
              errs = errs + 1;
              if (ByteMask !== eMask) ebm = ebm + 1;
              if (WordMasked !== eWM) ewm = ewm + 1;
              if (ValExtract !== eVE) begin
                eve = eve + 1;
                if (sg && eValid && (n == 1 || n == 2) && (ValExtract | (n == 1 ? 32'hFFFFFF00 : 32'hFFFF0000)) === eVE)
                  esign = esign + 1;   // looks exactly like missing sign extension
              end
              if (shown < 20) begin
                shown = shown + 1;
                $display("MISMATCH #%0d %0s MemShift=%0d SubIndex=%0d IsSigned=%0d WordFull=%h%0s",
                         errs, opname(ms, sg), ms, si, sg, pats[i], eValid ? "" : " (unsupported/misaligned)");
                if (ByteMask !== eMask)      $display("    ByteMask   got %b want %b", ByteMask, eMask);
                if (WordMasked !== eWM)      $display("    WordMasked got %h want %h", WordMasked, eWM);
                if (ValExtract !== eVE)      $display("    ValExtract got %h want %h", ValExtract, eVE);
              end
            end
          end
    $display("ByteAccess4_tb: %0d vectors (%0d patterns x 4 MemShift x 4 SubIndex x 2 IsSigned)", vecs, np);
    $display("ByteAccess4_tb: mismatching vectors %0d (ByteMask %0d, WordMasked %0d, ValExtract %0d; of which missing lb/lh sign extension %0d)",
             errs, ebm, ewm, eve, esign);
    $display("ByteAccess4_tb: ERRORS: %0d", errs);
    if (errs == 0) $display("PASS: ByteAccess4_tb");
    else           $display("FAIL: ByteAccess4_tb (%0d mismatching vectors)", errs);
    $finish;
  end
endmodule
