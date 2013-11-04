`include "CPUBusses.vh"

module StageM #(
    parameter COLT45_MEMWRITE=0
)(

    input `BUS_CPUGlobal_type CPUGlobal,
    // Inputs that peek into prior stage (to accommodate synchronous components this stage uses)
    input `BUS_ICTL_type _IControl, // Few are used (hopefully tools will prune)
    input  [31: 0]  _MemWValue,
    input  [31: 0]  _MemAddr,
    // Inputs held stable during our stage for us
    input `BUS_ICTL_type IControl,  // Not all are used (hopefully tools will prune)
    input  [31: 0]  MemAddr,
    input  [31: 0]  RegWValue,
    input  [31: 0]  PC,
    // Outputs fed back to prior stages
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_,
    output          WBK_CanFWD_,
    // Memory/IO drives
    output reg _hot_IO, _hot_BR, _hot_DC, _hot_IC, _hot_DB, _hot_IB,
    output [ 3: 0] _ByteMask, _WriteMask,
    output [31: 0] _WDataMasked,
    input  [31: 0] RData_IO, RData_BR, RData_DC, RData_DB
);

    wire clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

// _IControl & IControl taps
    wire [1:0] _DataWidth;
    wire _isWrite, _isRead;
    BUS_ICTL_tap TAP__ICTL
    ( ._BUS_(_IControl),    // Explicitly list unused taps (helps warnings)
        .MemWrite(_isWrite), .MemToReg(_isRead), .DataWidth(_DataWidth),
        .DestReg(),.Link(),
        .ALUOp(),.ALUSrcA(),.ALUSrcB(),.ISigned(),.MSigned(),.CmpOp(),.Jump(),.JR()
    );
    wire  [ 3: 0] _Target   = _MemAddr[31:28];
    wire  [ 1: 0] _SubAddr  = _MemAddr[ 1: 0];
    wire  [ 1: 0] _SubShift = (3 - _DataWidth);

// Compute some mask bytes/bits/values
    assign _WDataMasked = (_MemWValue) << (_SubShift*8) >> (_SubAddr*8);
    assign _ByteMask    = (   4'b1111) << (_SubShift  ) >> (_SubAddr  );
    assign _WriteMask   = (_isWrite) ? _ByteMask : 4'b0000;

always @(*) begin
    _hot_IO=1'b0; _hot_BR=1'b0; _hot_DC=1'b0; _hot_IC=1'b0; _hot_DB=1'b0; _hot_IB=1'b0;
    if (~stall && (_isRead || _isWrite)) case (_Target)
        4'b1000: _hot_IO = 1'b1;
        4'b0100: _hot_BR = !_isWrite;
`ifndef COLT45_pre2
        4'b0001: _hot_DC = 1'b1;
        4'b0010: _hot_IC = _isWrite && PC[30];
        4'b0011: begin
            _hot_DC = 1'b1; _hot_IC = _isWrite && PC[30];
        end
`ifndef COLT45_STRICT
//EXTRA: Scratchpad-RAM
        4'b0101: _hot_DB = 1'b1;
        4'b0110: _hot_IB = _isWrite && PC[30];
        4'b0111: begin
            _hot_DB = 1'b1; _hot_IB =  _isWrite && PC[30];
        end
`endif
`else
        4'b0001: _hot_DB = 1'b1;
        4'b0010: _hot_IB = _isWrite;
        4'b0011: begin
            _hot_DB = 1'b1; _hot_IB = _isWrite;
        end
`endif
    endcase
end


// NOTE: ABOVE is _IControl and other pre/setup /// BELOW is IControl and other post/fetched


// _IControl & IControl taps
    wire [1:0] DataWidth;
    wire isWrite, isRead, isLink;
    wire [4:0] DestReg;
    BUS_ICTL_tap TAP_ICTL
    ( ._BUS_(IControl), // Explicitly list unused taps (helps warnings)
        .MemWrite(isWrite), .MemToReg(isRead), .DataWidth(DataWidth),
        .DestReg(DestReg), .Link(isLink),
        .ALUOp(),.ALUSrcA(),.ALUSrcB(),.ISigned(),.CmpOp(),.Jump(),.JR(),.MSigned()
    );
    wire  [ 3: 0] Target   = MemAddr[31:28];
    wire  [ 1: 0] SubAddr  = MemAddr[ 1: 0];
    wire  [ 1: 0] SubShift = (3 - DataWidth);

    reg [31: 0] DataRead; // Registered elsewhere (is just a reg here because of always@*)
    always @(*) case (Target) // "Target" (for read data coming out after clock) NOT "_Target"
        4'b1000         : DataRead = RData_IO;
`ifndef COLT45_pre2
        4'b0100         : DataRead = RData_BR;
        4'b0001, 4'b0011: DataRead = RData_DC;
`ifndef COLT45_STRICT //TODO: Ensure no other references to these if STRICT mode!
        4'b0101, 4'b0111: DataRead = RData_DB; // Scratchpad-RAM
`endif
`else
        4'b0001, 4'b0011: DataRead = RData_DB;
`endif
        default: DataRead = `UNKNOWN(32);
    endcase // CAUTIOUS trapping of EVERY case

    wire [31: 0] DataLoad = DataRead << (SubAddr*8) >> (SubShift*8);

    // Might divorce WBK from FWD stuff more fully to clarify slightly different paths
    assign WBK_Reg_ = DestReg; // Expected to be zero when no writeback
    assign WBK_Val_ = (isRead) ? DataLoad : RegWValue; //Jump-Link already hijacked RegWValue
    assign WBK_CanFWD_ = !isRead && (DestReg !== 0);



// synthesis translate_off
generate if (COLT45_MEMWRITE) begin:_MEMWRITE_
    always@(posedge clk) if (~stall && _isWrite) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        $display("** [%h,%d] <= %h(%d) {%b}",
            _MemAddr, _MemAddr, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** TARG=%h W=%b: IO=%b BR=%b IC=%b DB=%b IB=%b",
            _Target, _isWrite, _hot_IO, _hot_BR, _hot_IC, _hot_DB, _hot_IB);
    end
end endgenerate
// synthesis translate_on

endmodule
