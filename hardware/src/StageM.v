`timescale 1ns / 1ps

`include "CPUBusses.vh"

module StageM(
    inout `BUS_CPUGlobal_type   CPUGlobal,
    input `BUS_ICTL_type        IControl,
    
    input  [31: 0]  ALUOut,
    input  [31: 0]  R2Value,
    input  [31: 0]  PCPLUS8,
    
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_
);
    parameter crap = "tastic";
    
    assign WBK_Reg_ = `ICTL_DestReg(IControl);
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? 32'b0 : 
                        `ICTL_Link(IControl) ? PCPLUS8 : ALUOut;
    
endmodule
