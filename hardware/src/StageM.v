`timescale 1ns / 1ps

`include "CPUBusses.vh"

module StageM(
    inout `BUS_CPUGlobal_type   CPUGlobal,  // Not used (at least not clock, yet)
    inout `BUS_MEMIO_type       MemoryIO,
    
    input `BUS_ICTL_type        IControl,
    input  [31: 0]  ALUOut,
    input  [31: 0]  R2Value,
    input  [31: 0]  PCPLUS8,
    
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_
);
    parameter crap = "tastic";
    wire   [ 3: 0] WriteByteMask = (`ICTL_MemWrite(IControl)) ? 4'b1111 : 4'b0000;
                    //TODO: ^^^ Temporarily write to all bytes ^^^
    wire   [31: 0] DataWrite = R2Value;
    wire   [31: 0] DataRead;
    
    BUS_MEMIO_tun
    ( ._BUS_(MemoryIO),
        .Addr(ALUOut), //TODO: Drive with Unknown when not MemWrite
        .WEnab(WriteByteMask),
        .WData(DataWrite),
        .RData(DataRead)
    );
    
    assign WBK_Reg_ = `ICTL_DestReg(IControl);
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? DataRead : 
                        `ICTL_Link(IControl) ? PCPLUS8 : ALUOut;
    
endmodule
