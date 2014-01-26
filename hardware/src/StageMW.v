`include "cpuglobal.vh"

module StageMW (
//NOTE:Currently just asynchronous "control" logic!
//    input clk, rst, stall,

    // Inputs that peek into prior stage (to accommodate synchronous components this stage uses)
    input  [31: 0]  _MemAddr,
    input  [31: 0]  _MemWValue,
    input  [ 1: 0]  _MemShift,
    input           _MemWrite, _MemToReg, _PCinBIOS,

    // Inputs held stable during our stage for us
    input  [31: 0]  MemAddr_MW,
    input  [31: 0]  RegWValue_MW,
    input  [ 4: 0]  DestReg_MW,
    input  [ 1: 0]  MemShift_MW,
    input           MemToReg_MW,

    // Outputs fed back to prior stages
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_,
    output          WBK_CanFWD_,

    // Memory/IO drives
    output reg _hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR,
    output [ 3: 0] _ByteMask, _WriteMask,
    output [31: 0] _WDataMasked,
    input  [31: 0] RData_IO, RData_BR, RData_DC, RData_DB
);

    wire  [ 3: 0] _Target   = _MemAddr[31:28];
    wire  [ 1: 0] _SubIndex = _MemAddr[ 1: 0];

// Compute some mask bytes/bits/values
//    assign _ByteMask    = (   4'b1111) << (_MemShift  ) >> (_SubIndex  );
//    assign _WDataMasked = (_MemWValue) << (_MemShift*8) >> (_SubIndex*8);
    ByteAccess4 ba4_write (
        .MemShift(_MemShift), .SubIndex(_SubIndex), .WordFull(_MemWValue),
        .ByteMask(_ByteMask), .WordMasked(_WDataMasked), .ValExtract()
    );
    assign _WriteMask = (_MemWrite) ? _ByteMask : 4'b0000;

    always @(*) begin
        {_hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR} = 0;
        if (_MemToReg || _MemWrite) begin
            case (_Target)
                4'b1000: _hot_IO = 1'b1;
                4'b0100: _hot_BR = !_MemWrite; //Read-only
                4'b0011: begin
                        _hot_DC = 1'b1;
                        _hot_IC = _MemWrite && _PCinBIOS;
                    end
                4'b0010: _hot_IC = _MemWrite && _PCinBIOS;
                4'b0001: _hot_DC = 1'b1;
`ifndef COLT45_STRICT
                4'b0110: _hot_IB = _MemWrite; //XTRA: Scratchpad-DMEM
                4'b0101: _hot_DB = 1'b1; //XTRA: Scratchpad-DMEM
`endif //(!) COLT45_STRICT
                4'b1100: _hot_ISR = _MemWrite; //ISR//
            endcase
        end
    end


// NOTE: ABOVE THIS SPOT is "_IControl" and other pre/setup staging //
// NOTE: BELOW THIS SPOT is "IControl" and other post/fetched processing //

    wire  [ 3: 0] Target   = MemAddr_MW[31:28];
    wire  [ 1: 0] SubIndex = MemAddr_MW[ 1: 0];

    reg [31: 0] DataRead; // Registered elsewhere (is just a reg here because of always@*)
    always @(*) begin
        case (Target) // "Target" (for read data coming out after clock) NOT "_Target"
            4'b1000         : DataRead = RData_IO;
            4'b0100         : DataRead = RData_BR;
            4'b0001, 4'b0011: DataRead = RData_DC;
`ifndef COLT45_STRICT //TODO: Ensure no other references to these if STRICT mode!
            4'b0101         : DataRead = RData_DB; // Scratchpad-RAM
`endif
            default: DataRead = 32'd0;
        endcase // CAUTIOUS trapping of EVERY case
    end

    wire [31: 0] DataLoad;
//  assign DataLoad = (DataRead) << (SubIndex*8) >> (MemShift_MW*8);
    ByteAccess4 ba4_read ( //NOTE: Swap SubIndex & MemShift_MW to reverse
        .MemShift(MemShift_MW), .SubIndex(SubIndex), .WordFull(DataRead),
        .ByteMask( ), .WordMasked(), .ValExtract(DataLoad)
    );

// WBK outputs (including "can forward" signal)
    assign WBK_Reg_     = DestReg_MW; //ZERO when no register writeback is happening
    assign WBK_Val_     = (DestReg_MW == 5'd0) ? `UNKNOWN(32)
                            : ( (MemToReg_MW) ? DataLoad : RegWValue_MW ); //Jump-Link uses RegWValue_MW
    assign WBK_CanFWD_  = (DestReg_MW == 5'd0) ? 1'b0
                            : ( (MemToReg_MW) ? 1'b0 : 1'b1 ); //Covers CopRead too (forwarding allowed)

endmodule
