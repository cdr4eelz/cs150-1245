`include "CPUBusses.vh"

module StageWF #(
    parameter   [31: 0] bootPC = 32'h00000000
) (
    inout  [ 2: 0] CPUGlobal,
    output [11: 0] IMEM_read_addr,
    input  [31: 0] IMEM_read_data,

    input  [31: 0] PCNext,
    
    output [31: 0] PC,
    output [31: 0] INST
);
    wire  clk, rst, stl;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
    reg  RST_REG;
    
    wire [31: 0] PC_HOT;
    assign PC_HOT = (RST_REG) ? bootPC : PCNext;
    
    reg [31: 0] PC_REG;
    always @(posedge clk) begin
        RST_REG <= rst;
        PC_REG  <= PC_HOT;
    end
    
    assign IMEM_read_addr[11:0] = PC_HOT[13:2];   // Do we worry about illegal addresses?
    assign PC = PC_REG;
    assign INST = IMEM_read_data;
    
endmodule
