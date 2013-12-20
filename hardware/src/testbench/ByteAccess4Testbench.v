`timescale 1ns/1ns

module ByteAccess4Testbench;

// Register and wires to test the ByteAccess4 decode/shift
    reg [ 1:0] MemShift;
    reg [ 1:0] SubIndex;
    reg [31:0] WordFull;
    wire [ 3:0] ByteMask;
    wire [ 3:0] _ByteMask;
    wire [31:0] WordMasked;
    wire [31:0] _WordMasked;
    wire [31:0] ValExtract;
    wire [31:0] _ValExtract;

// Compute some mask bytes/bits/values
    ByteAccess4 DUT (
        .MemShift(MemShift), .SubIndex(SubIndex), .WordFull(WordFull),
        .ByteMask(ByteMask), .WordMasked(WordMasked), .ValExtract(ValExtract)
    );

// Reference values
    assign _ByteMask   = ( 4'b1111) << (MemShift  ) >> (SubIndex  );
    assign _WordMasked = (WordFull) << (MemShift*8) >> (SubIndex*8);
    assign _ValExtract = (WordFull) << (SubIndex*8) >> (MemShift*8);

    task CHECK_RESULTS;
        begin
            $display("MS:%d SI:%d WF:%h ==> BM:%b WM:%h VE:%h",
                     MemShift, SubIndex, WordFull,
                     _ByteMask, _WordMasked, _ValExtract);
            if ({ ByteMask, WordMasked, ValExtract} !=
                {_ByteMask,_WordMasked,_ValExtract}) begin
                $display("FAIL: Got BM:%b WM:%h VE:%h",
                         ByteMask, WordMasked, ValExtract);
            end
        end
    endtask

    task CHECK_SWEEP; //Only specific values are allowed
        input [31:0] word;
        begin
            WordFull = word;
            MemShift = 2'd0;
            SubIndex = 2'd0; #10; CHECK_RESULTS();
            MemShift = 2'd2;
            SubIndex = 2'd0; #10; CHECK_RESULTS();
            SubIndex = 2'd2; #10; CHECK_RESULTS();
            MemShift = 2'd3;
            SubIndex = 2'd0; #10; CHECK_RESULTS();
            SubIndex = 2'd1; #10; CHECK_RESULTS();
            SubIndex = 2'd2; #10; CHECK_RESULTS();
            SubIndex = 2'd3; #10; CHECK_RESULTS();
        end
    endtask

// Testing logic:
    initial begin
        CHECK_SWEEP(32'hFABCDE83);
        $display("All tests passed!");
        $finish();
    end
endmodule
