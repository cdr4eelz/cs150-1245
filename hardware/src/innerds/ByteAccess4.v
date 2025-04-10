module ByteAccess4 #(
    parameter BigEndian = 1 //NOTE: Endianess option UNIMPLEMENTED (always BIG)!!!
) (
    input wire [ 1: 0]  MemShift,
    input wire [ 1: 0]  SubIndex,
    output reg [ 3: 0]  ByteMask,
    input wire [31: 0]  WordFull,
    output reg [31: 0]  WordMasked,
    output reg [31: 0]  ValExtract
);
//"Clipping" modeled after "assign dout = data >> {offset_hold, 5'b0}" from Cache.v:
//  wire [3:0] BMaskRaw;
//  assign BMaskRaw = 4'b1111 << MemShift[1:0]; // [1:0] redundant, of course.
//  assign ByteMask = RawMask >> SubIndex[1:0];

////wire [31:0] WordMaskRaw = (WordFull << {MemShift[1:0], 3'b000};
////assign WordMasked    = (WordMaskRaw >> {SubIndex[1:0], 3'b000};

//  assign WordMasked = {   WordFull[31:24] & ByteMask[3],
//                          WordFull[23:16] & ByteMask[2],
//                          WordFull[15: 8] & ByteMask[1],
//                          WordFull[ 7: 0] & ByteMask[0] };

// Modeled in lookup-table style:
    always @(*) case ( {MemShift, SubIndex} )
        4'b00_00: ByteMask = 4'b1111;
        4'b10_00: ByteMask = 4'b1100;
        4'b10_10: ByteMask = 4'b0011;
        4'b11_00: ByteMask = 4'b1000;
        4'b11_01: ByteMask = 4'b0100;
        4'b11_10: ByteMask = 4'b0010;
        4'b11_11: ByteMask = 4'b0001;
        default: ByteMask = 4'b0000;
    endcase

    always @(*) case ( {MemShift, SubIndex} )
        4'b00_00: WordMasked = { WordFull[31:24], WordFull[23:16], WordFull[15: 8], WordFull[ 7: 0] };
        4'b10_00: WordMasked = { WordFull[15: 8], WordFull[ 7: 0],            8'd0,           8'd00 };
        4'b10_10: WordMasked = {            8'd0,            8'd0, WordFull[15: 8], WordFull[ 7: 0] };
        4'b11_00: WordMasked = { WordFull[ 7: 0],            8'd0,            8'd0,            8'd0 };
        4'b11_01: WordMasked = {            8'd0, WordFull[ 7: 0],            8'd0,            8'd0 };
        4'b11_10: WordMasked = {            8'd0,            8'd0, WordFull[ 7: 0],            8'd0 };
        4'b11_11: WordMasked = {            8'd0,            8'd0,            8'd0, WordFull[ 7: 0] };
        default: WordMasked = 32'd0;
    endcase

    always @(*) case ( {MemShift, SubIndex} )
        4'b00_00: ValExtract = { WordFull[31:24], WordFull[23:16], WordFull[15: 8], WordFull[ 7: 0] };
        4'b10_00: ValExtract = {            8'd0,            8'd0, WordFull[31:24], WordFull[23:16] };
        4'b10_10: ValExtract = {            8'd0,            8'd0, WordFull[15: 8], WordFull[ 7: 0] };
        4'b11_00: ValExtract = {            8'd0,            8'd0,            8'd0, WordFull[31:24] };
        4'b11_01: ValExtract = {            8'd0,            8'd0,            8'd0, WordFull[23:16] };
        4'b11_10: ValExtract = {            8'd0,            8'd0,            8'd0, WordFull[15: 8] };
        4'b11_11: ValExtract = {            8'd0,            8'd0,            8'd0, WordFull[ 7: 0] };
        default: ValExtract = 32'd0;
    endcase
endmodule

/*
  WxHB (word,  xxx, half, byte)   (word,  xxx, half, byte)  <<<-- Opcode "Word, x, Half, bByte"
          11,  x10,   01,   00       11,  x10,   01,   00
Sub        3,   x2,    1,    0        3,   x2,    1,    0
0  00   1111,     , 0011, 0001     1111,     , 0011, 0001
1  01                     0010                       0001
2  10               1100, 0100                 0011, 0001
3  11                     1000                       0001
    (Sub is shift distance; Size determines # of 1-bits from right)

~WxHB=~(word,  xxx, half, byte)  ~(word,  xxx, half, byte)  <<<-- (3 - WxHB) = MemShift amount
          00,  x01,   10,   11       00,  x01,   10,   11
Sub        0,   x1,    2,    3        0,   x1,    2,    3
0  00  *1111,     , 1100, 1000     1111,     , 1100, 1000
1  01        *            0100                       1000
2  10  -1100,     ,*0011, 0010                 1100, 1000
3  11  -1000,-0100,-0010,*0001                       1000
    (~Size is left shift distance, size shift right distance after msb-cliped)
*/
