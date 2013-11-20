module ByteAccess4 #(
    parameter BigEndian = 0 //TODO: Endianess option UNIMPLEMENTED!!!
) (
    input  [ 1: 0]  MemShift,
    input  [ 1: 0]  SubIndex,
    output [ 3: 0]  ByteMask,
    input  [31: 0]  WordFull,
    output [31: 0]  WordMasked
);
    assign ByteMask     = ( 4'b1111) << (MemShift  ) >> (SubIndex  );
    assign WordMasked   = (WordFull) << (MemShift*8) >> (SubIndex*8);
//TODO: Implement as "16" entry case (only 7 entries are valid)
endmodule

/*
 3  x2   1   0
11  10  01  00
00  01  10  11
 0  x1   2   3

       (word,  inv, half, byte)   (word,  inv, half, byte)
Sub        3,   2x,    1,    0        3,   2x,    1,    0
0  00   1111,     , 0011, 0001     1111,     , 0011, 0001
1  01                     0010                       0001
2  10               1100, 0100                 0011, 0001
3  11                     1000                       0001
    (Sub is shift distance; Size determines # of bits)

      ~(word,  inv, half, byte)  ~(word,  inv, half, byte)
Sub        0,   1x,    2,    3        0,   1x,    2,    3
0  00   1111,     , 1100, 1000     1111,     , 1100, 1000
1  01                     0100                       1000
2  10               0011, 0010                 1100, 1000
3  11                     0001                       1000
    (~Size is left shift distance, size shift right)
*/
