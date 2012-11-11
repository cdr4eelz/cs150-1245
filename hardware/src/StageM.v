`timescale 1ns / 1ps

`include "CPUBusses.vh"

module StageM(
    inout `BUS_CPUGlobal_type   CPUGlobal,  // Clock not used (others not used yet either)
    inout `BUS_MEMIO_type       MemoryIO,
    
    input `BUS_ICTL_type        _IControl,
    input `BUS_ICTL_type        IControl,
    input  [31: 0]  _MemAddr,
    input  [31: 0]  _MemWValue,
    input  [31: 0]  RegWValue,
    input  [31: 0]  PCPLUS8,
    
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_,
    output          WBK_CanFWD_
);
    parameter crap = "tastic";
    wire   [ 3: 0] _TargetMask = (`ICTL_MemWrite(_IControl)) ? 4'b1111 : 4'b0000;
    wire   [ 3: 0] _WByteMask = (`ICTL_MemWrite(_IControl)) ? 4'b1111 : 4'b0000;
                    //TODO: ^^^ Temporarily write to all bytes ^^^
    wire   [11: 0] _AddressRW = _MemAddr[13:2]; // TODO: Drive with `Unknown when ~|WriteByteMask
    wire   [31: 0] DataRead;
    
    BUS_MEMIO_tun BUS_MEMIO
    ( ._BUS_(MemoryIO),
        .Addr   (_AddressRW),   // TODO: Drive with `Unknown when ~|WriteByteMask
        .TMask  (_TargetMask),
        .BMask  (_WByteMask),
        .WData  (_MemWValue),   // ^^^these too.
        .RData  (DataRead)      // This is registered by the memory itself
    );
    
    assign WBK_Reg_ = `ICTL_DestReg(IControl); // Expected to be zero when no writeback
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? DataRead : // Using DataRead for WB would be sync/sync
                        `ICTL_Link(IControl) ? (PCPLUS8) : RegWValue;
    assign WBK_CanFWD_ = !`ICTL_MemToReg(IControl) && (WBK_Reg_ != 0);
    
endmodule
