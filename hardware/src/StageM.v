`include "CPUBusses.vh"

module StageM(
    inout  [ 2:0 ] CPUGlobal
    
);
   
    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
endmodule
