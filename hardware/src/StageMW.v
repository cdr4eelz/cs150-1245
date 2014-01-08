`include "cpuglobal.vh"

module StageMW (
//NOTE:Currently just asynchronous "control" logic!
//    input clk, rst, stall,

    // Inputs that peek into prior stage (to accommodate synchronous components this stage uses)
    input `BUS_ICTL_type _IControl, // Few are used (hopefully tools will prune)
    input  [31: 0]  _MemWValue,
    input  [31: 0]  _MemAddr,
    input           _PCinBIOS,

    // Inputs held stable during our stage for us
    input `BUS_ICTL_type IControl,  // Not all are used (hopefully tools will prune)
    input  [31: 0]  MemAddr,
    input  [31: 0]  RegWValue,

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

//TODO: Move almost all to instruction decode (makes pre/post clock activities legitimate)

// _IControl taps
    wire [1:0] _MemShift;
    wire _isMemWrite, _isMemRead;
    BUS_ICTL_tap TAP__ICTL
    ( ._BUS_(_IControl),    // Explicitly list unused taps (helps warnings)
        .MemToReg(_isMemRead), .MemShift(_MemShift),
        .MemWrite(_isMemWrite), .DestReg(),
        .ALUOp(),.ALUSrcA(),.ALUSrcB(),.ISigned(),.MSigned(),.CmpOp(),.Jump(),.JR(),.Link()
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
    assign _WriteMask = (_isMemWrite) ? _ByteMask : 4'b0000;

    always @(*) begin
        {_hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR} = 0;
        if (_isMemRead || _isMemWrite) begin
            case (_Target)
                4'b1000: _hot_IO = 1'b1;
                4'b0100: _hot_BR = !_isMemWrite; //Read-only
                4'b0011: begin
                        _hot_DC = 1'b1;
                        _hot_IC = _isMemWrite && _PCinBIOS;
                    end
                4'b0010: _hot_IC = _isMemWrite && _PCinBIOS;
                4'b0001: _hot_DC = 1'b1;
`ifndef COLT45_STRICT
                4'b0110: _hot_IB = _isMemWrite; //XTRA: Scratchpad-DMEM
                4'b0101: _hot_DB = 1'b1; //XTRA: Scratchpad-DMEM
`endif //(!) COLT45_STRICT
                4'b1100: _hot_ISR = _isMemWrite; //ISR//
            endcase
        end
    end


// NOTE: ABOVE THIS SPOT is "_IControl" and other pre/setup staging //
// NOTE: BELOW THIS SPOT is "IControl" and other post/fetched processing //


// IControl taps
    wire [1:0] MemShift;
    wire isMemRead;
    wire [4:0] DestReg;
    BUS_ICTL_tap TAP_ICTL
    ( ._BUS_(IControl), // Explicitly list unused taps (helps warnings)
        .MemToReg(isMemRead), .MemShift(MemShift),
        .MemWrite(), .DestReg(DestReg),
      .ALUOp(),.ALUSrcA(),.ALUSrcB(),.ISigned(),.CmpOp(),.Jump(),.JR(),.MSigned(),.Link()
    );
    wire  [ 3: 0] Target   = MemAddr[31:28];
    wire  [ 1: 0] SubIndex = MemAddr[ 1: 0];

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
//  assign DataLoad = (DataRead) << (SubIndex*8) >> (MemShift*8);
    ByteAccess4 ba4_read ( //NOTE: Swap SubIndex & MemShift to reverse
        .MemShift(MemShift), .SubIndex(SubIndex), .WordFull(DataRead),
        .ByteMask( ), .WordMasked(), .ValExtract(DataLoad)
    );

// WBK outputs (including "can forward" signal)
    assign WBK_Reg_     = DestReg; //ZERO when no register writeback is happening
    assign WBK_Val_     = (DestReg == 5'd0) ? `UNKNOWN(32)
                            : ( (isMemRead) ? DataLoad : RegWValue ); //Jump-Link uses RegWValue
    assign WBK_CanFWD_  = (DestReg == 5'd0) ? `UNKNOWN(1)
                            : ( !isMemRead ); //Covers CopRead too (forwarding allowed)

endmodule
