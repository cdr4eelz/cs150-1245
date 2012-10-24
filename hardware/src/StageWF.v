`include "CPUBusses.vh"

module StageWF(
    inout  [ 2:0 ] CPUGlobal,
    output [31:0 ] IMEM_read_addr,
    input  [31:0 ] IMEM_read_data,

    input  PCNext,
    
    output [31:0 ] PC,
    output [31:0 ] INST
);
    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
endmodule
