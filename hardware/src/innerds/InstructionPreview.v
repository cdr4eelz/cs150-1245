`include "cpuglobal.vh"

module InstructionPreview #(
    parameter DD=`COLT45_DD
)(
    // Inputs to decode (PC to pin down branch/jump)
    input [31:0 ] _inst,
    // Preview basics about instruction
    output couldBranch
);

//Could just use InstructionControl and let synthesis prune out unused junk!
//Could use a pretty simple casex too.

    wire [5:0] _opcode_ = _inst[31:26];
    wire [5:0] _funct_  = _inst[5:0];

    wire isBSimple  = (_opcode_[5:2] == 4'b0001__);
    wire isBGELTZ   = (_opcode_[5:0] == 6'b000001);
    wire isJType    = (_opcode_[5:1] == 5'b00001_);

    wire isRType    = (_opcode_[5:0] == 6'b000000);
    wire isRJump    = (isRType && (_funct_[5:1] == 5'b00100_));

    assign couldBranch  = (isBSimple || isBGELTZ || isJType || isRJump);

endmodule
