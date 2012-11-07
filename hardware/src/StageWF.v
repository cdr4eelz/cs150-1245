`timescale 1ns / 1ps

`include "CPUBusses.vh"

module StageWF #(
    parameter   [31: 0] bootPC = 32'h10000000   // 2-lsb must be 0, upper nibble ought be 1???
) (
    input  [ 2: 0] CPUGlobal,
    output [11: 0] IMEM_read_addr,
    input  [31: 0] IMEM_read_data,
    
    input          DOBranch,
    input  [31: 0] PCBranch,
    
    output [31: 0] PC,
    output [31: 0] INST,
    output reg [15: 0] STEPCOUNT
);
    wire  clk, rst, stl;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
    reg [31: 0] PC_REG;
    always @(posedge clk) begin //TODO: stall
        if (rst) begin
            PC_REG = bootPC;
            STEPCOUNT = 0;
        end else begin
            PC_REG = (DOBranch) ? PCBranch : (PC_REG+4);
            STEPCOUNT = STEPCOUNT + 1;
        end
    end
    
    assign IMEM_read_addr[11:0] = PC_REG[13:2];   // Do we worry about illegal addresses?
    assign PC   = PC_REG;
    assign INST = IMEM_read_data;
    
endmodule
