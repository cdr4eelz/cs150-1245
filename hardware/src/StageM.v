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
    wire  [ 3: 0] _TargetMask  = _MemAddr[31:28];  // Top nibble to direct target
    wire  [11: 0] _AddressRW   = _MemAddr[13:2];   // TODO: Drive with `Unknown when ~|WriteByteMask
    wire  [ 1: 0] _SubAddr     = _MemAddr[1:0];
    wire  [ 1: 0] _SubWidth    = (3 - `ICTL_DataWidth(_IControl));
    wire  [ 3: 0] _WByteMask   = (!`ICTL_MemWrite(_IControl)) ? 4'b0000 :
                                    4'b1111 << _SubWidth >> _SubAddr;
    wire  [31: 0] _WDataMasked = _MemWValue << (_SubWidth*8) >> (_SubAddr*8);
    
    wire  [31: 0] DataRead;
    BUS_MEMIO_tun BUS_MEMIO
    ( ._BUS_(MemoryIO),
        .Addr   (_AddressRW),   // TODO: Drive with `Unknown when not reading or writing
        .TMask  (_TargetMask),
        .BMask  (_WByteMask),
        .WData  (_WDataMasked),   // ^^^these too.
        .RData  (DataRead)      // This is registered by the memory itself
    );
    
    // Important to note the very cautious use of registered vs passthrough values,
    //   control signals, ets. (Example, DataWidth for read comes from IControl but
    //   DataWidth for write came from _IControl).
    
    wire  [ 1: 0] SubAddr   = RegWValue[1:0];
    wire  [ 1: 0] SubWidth  = (3 - `ICTL_DataWidth(IControl));
    wire  [31: 0] DataLoad  = DataRead << (SubAddr*8) >> (SubWidth*8);
    // ^^ I guess I'm hoping this stuff washes out with optimization! Is nice to have so
    //    expanded out like this for debugging/simulation purposes, though :)

    assign WBK_Reg_ = `ICTL_DestReg(IControl); // Expected to be zero when no writeback
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? DataLoad :
                        `ICTL_Link(IControl) ? (PCPLUS8) : RegWValue;
    assign WBK_CanFWD_ = !`ICTL_MemToReg(IControl) && (WBK_Reg_ != 0);
    
endmodule
