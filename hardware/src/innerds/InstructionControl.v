`include "cpuglobal.vh"
`include "opcode.vh"

//TODO: Eliminate PC junk from decode (especially an ADDER)!!!

module InstructionControl #(
    parameter DD=`COLT45_DD
)(
    // Inputs to decode (PC to pin down branch/jump)
    input [31:0 ] _inst,
    // Global or post-DX control signals
    output [ 1:0 ] MemShift,
    output [ 4:0 ] DestReg,
    output         MemSigned, MemToReg, MemWrite,
    // Values consumed mostly by DX stage
    output [ 3:0 ] ALUOp,
    output [ 2:0 ] CmpOp,
    output         ALUSrcA, ALUSrcB, ISigned, Jump, JR, Link, Branch,
    output [31:0 ] SIMMED, UIMMED,
    output [27:0 ] NEARADDR,
    output [ 4:0 ] SRC1, SRC2, SHAMT,
    // COP0 additions
    output [ 4:0 ] COPADDR,
    output COPREAD, COPWRITE
);

    // Some simple functions (not too powerful, just for experience)
    function [31:0] SEXT16_32;
        input [15:0] in16;
        SEXT16_32 = {{16{in16[15]}}, in16};
    endfunction
    function [31:0] ZEXT16_32;
        input [15:0] in16;
        ZEXT16_32 = {16'b0, in16};
    endfunction

    // OPCODE and major categories
    wire isRType, isSType, isJType, isIType;
    wire [ 5: 0] _opcode_ = _inst[31:26];
    assign isRType  = (_opcode_[5:0] == 6'b000000);
    assign isSType  = (_opcode_[5:0] == 6'b010000); //COP0 "type" (maybe any "special" opcodes???)
    assign isJType  = (_opcode_[5:1] == 5'b00001_);
    assign isIType  = !(isRType || isSType || isJType);

    // Simple peal-off wire ranges
    wire [ 4: 0] _rs_, _rt_, _rd_, _shamt_;
    wire [ 5: 0] _funct_;
    wire [15: 0] _immediate_;
    wire [25: 0] _nearaddr_;
    assign _rs_         = `UNKWIFN( _inst[25:21]
                            ,  5, isRType || isIType || isSType); // !isJType
    assign _rt_         = `UNKWIFN( _inst[20:16]
                            ,  5, isRType || isIType || isSType);
    assign _rd_         = `UNKWIFN( _inst[15:11]
                            ,  5, isRType || isSType);
    assign _shamt_      = `UNKWIFN( _inst[10:6 ]
                            ,  5, isRType);
    assign _funct_      = `UNKWIFN( _inst[ 5:0 ]
                            ,  6, isRType);
    assign _immediate_  = `UNKWIFN( _inst[15:0 ]
                            , 16, isIType);
    assign _nearaddr_   = `UNKWIFN( _inst[25:0 ]
                            , 26, isJType);

    // These characteristics could come from lookup table but this is more enlightening!
    wire #DD isMemory, isMStore, isMLoad, isIComp, isISigned, isMSigned;
    wire #DD isCopRead, isCopWrite; //ISR//
    assign isMemory    = (_opcode_[5:4] == 2'b10);
    assign isMLoad     = (_opcode_[5:3] == 3'b100);
    assign isMStore    = (_opcode_[5:3] == 3'b101);
    assign isIComp     = (_opcode_[5:3] == 3'b001);
    assign isISigned   = (isMemory || (isIComp && !_opcode_[2]));
    assign isMSigned   = (isMemory && !isMStore && !_opcode_[1] && !_opcode_[2]);
    assign isCopRead   = (isSType && (_rs_ == `COP0_FROM));
    assign isCopWrite  = (isSType && (_rs_ == `COP0_TO));
    wire #DD isRShift, isRShiftI, isRShiftR, isROther;
    assign isRShift    = (isRType && (_funct_[5:3] == 3'b000));
    assign isRShiftI   = (isRShift && (_funct_[2] == 1'b0));
    assign isRShiftR   = (isRShift && (_funct_[2] == 1'b1));
    assign isROther    = (isRType && (_funct_[5:4] == 2'b10));
    wire #DD isIJump, isRJump, isJump, isLink;
    assign isIJump     = isJType;
    assign isRJump     = (isRType && (_funct_[5:1] == 5'b00100));
    assign isJump      = (isIJump || isRJump);
    assign isLink      = (isIJump && _opcode_[0]) || (isRJump && _funct_[0]); //JAL/JALR have low-bit==1
    wire #DD isBSimple, isBGELTZ, isBranch, isBranchX, isBranch0;
    assign isBSimple   = (_opcode_[5:2] == 4'b0001);
    assign isBGELTZ    = (_opcode_ == 6'b000001);
    assign isBranch    = (isBSimple || isBGELTZ);
    assign isBranchX   = (_opcode_[5:1] == 5'b00010);
    assign isBranch0   = (isBGELTZ || (_opcode_[5:1] == 5'b00011));

    assign SIMMED   = SEXT16_32(_immediate_);
    assign UIMMED   = ZEXT16_32(_immediate_);
    assign SHAMT    = (isRShiftI) ? _shamt_ : 5'd0;
    assign SRC1     = (!isJType && !isRShiftI) ? _rs_ : 5'd0;
    assign SRC2     = (isBranch0) ? 5'd0 :
                       (isROther || isBranchX || isRShift || isMStore || isCopWrite)
                           ? _rt_ : 5'd0;

    assign COPADDR  = (isCopRead || isCopWrite) ? _rd_ : 5'd0;
    assign COPREAD  = isCopRead;
    assign COPWRITE = isCopWrite;

    // Embed existing ALUDecoder from lab
    ALUdec ALUDecoder(
        .opcode(_opcode_), .funct(_funct_),
        .ALUop(ALUOp)
    );

    assign MemSigned = isMSigned, MemToReg = isMLoad, MemWrite = isMStore;
    assign MemShift = `UNKWIFN(
                        (~_opcode_[1:0])
                        ,  2, isMemory); // ~x == 3-x (1's complement)
    assign DestReg  = (isJump)
                        ? ( (isLink) // JUMP-LINK to $ra else $0
                            ? 5'd31
                            : 5'd0)
                        : ( (isRType)
                            ? _rd_
                            : ( (isMLoad || isIComp || isCopRead ) ? _rt_ : 5'd0)
                        );

    assign ISigned = isISigned, Jump = isJump, JR = isRJump, Link = isLink, Branch = isBranch,
            ALUSrcA = isRShiftI, ALUSrcB = (isMemory || isIComp),
            NEARADDR = {_nearaddr_,2'b00};
    assign CmpOp    = (isBSimple)
                        ? _opcode_[2:0]
                        : ( (isBGELTZ)
                            ? (_opcode_[2:0] << _rt_[0]) //TODO: Strange formula :(
                            : ((isJump) ? 3'b011 : 3'b000) //TODO: Use constant names!
                        );

endmodule
