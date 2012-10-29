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
    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
    wire [31: 0] PC_HOT;
    assign PC_HOT = (reset) ? bootPC : PCNext;
    
    reg [31: 0] PC_REG;
    always @(posedge clk) begin
        PC_REG <= PC_HOT;
    end
    
    assign IMEM_read_addr = PC_HOT[11:0];   // Do we worry about illegal addresses?
    assign PC = PC_REG;
    assign INST = IMEM_read_data;
    initial begin
        $monitor("iWF: %h %h | %h %h %h", clk, reset, PC, IMEM_read_data, INST);
    end
    
endmodule
