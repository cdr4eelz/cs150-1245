`include "../cpuglobal.vh"

module InstructionPreview #(
    parameter DD=`COLT45_DD,
    parameter USE_DECODER=1
)(
    // Inputs to decode (PC to pin down branch/jump)
    input [31:0 ] _inst,
    // Preview basics about instruction
    output couldBranch
);

//TODO:Consider a pretty simple casex for this
generate if (USE_DECODER) begin:_DECODER_
/* verilator lint_off PINCONNECTEMPTY */
    InstructionControl decodeControl(
        ._inst(_inst),
        // Global control signals
        .MemShift(), .MemSigned(),
        .MemToReg(), .MemWrite(),
        // Standard control signals only used locally
        .ALUOp(), .ALUSrcA(), .ALUSrcB(), .DestReg(),
        .ISigned(), .CmpOp(), .Jump(), .JR(), .Link(), .Branch(),
        // Locally used special values
        .IMMED(), .NEARADDR(),
        .SRC1(), .SRC2(), .COPWRITE(), .COPADDR(),
        .SHAMT(), .COPREAD(),
        // Specific to Instruction-Preview
        .Deviant(couldBranch)
    );
/* verilator lint_on PINCONNECTEMPTY */
end else begin:_COMPUTE_
    wire [5:0] _opcode_ = _inst[31:26];
    wire [5:0] _funct_  = _inst[5:0];

    wire isBSimple  = (_opcode_[5:2] == 4'b0001__);
    wire isBGELTZ   = (_opcode_[5:0] == 6'b000001);
    wire isJType    = (_opcode_[5:1] == 5'b00001_);

    wire isRType    = (_opcode_[5:0] == 6'b000000);
    wire isRJump    = (isRType && (_funct_[5:1] == 5'b00100_));

    assign couldBranch  = (isBSimple || isBGELTZ || isJType || isRJump);
end endgenerate

endmodule
