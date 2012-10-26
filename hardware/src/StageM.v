`include "CPUBusses.vh"

module StageM(
    inout `BUS_CPUGlobal_type   CPUGlobal,
    input `BUS_IControl_type    IControl,
    
    input  [31: 0]  ALUOut,
    input  [31: 0]  R2Value,
    input  [31: 0]  PCPLUS8
    
);
   
    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
endmodule
