`include "cpuglobal.vh"
`include "opcode.vh"

module InstructionControl #(
    parameter DD=`COLT45_DD
)(
    // Input instruction to decode (PC pinds down branch/jump target later)
    input [31:0 ] _inst,
    // Global or post-DX control signals
    output [ 1:0 ] MemShift,
    output [ 4:0 ] DestReg,
    output         MemSigned, MemToReg, MemWrite,
    // Values consumed mostly by DX stage
    output [ 3:0 ] ALUOp,
    output [ 2:0 ] CmpOp,
    output         ALUSrcA, ALUSrcB, ISigned, Jump, JR, Link, Branch,
    output [15:0 ] IMMED,
    output [27:0 ] NEARADDR,
    output [ 4:0 ] SRC1, SRC2, SHAMT,
    // COP0 additions
    output [ 4:0 ] COPADDR,
    output COPREAD, COPWRITE
);

    // OPCODE and major categories
    wire isRType, isJType, isIType, isCType;
    wire [ 5: 0] _opcode_ = _inst[31:26];
    assign isRType  = (_opcode_[5:0] == 6'b000000); //AKA SPECIAL category
    assign isJType  = (_opcode_[5:1] == 5'b00001_);
    assign isCType  = (_opcode_[5:0] == 6'b010000); //COP0 "type" (hacked in here)
    assign isIType  = !(isRType || isJType || isCType);

    // Simple peal-off wire ranges
    wire [ 4: 0] _rs_, _rt_, _rd_, _shamt_;
    wire [ 5: 0] _funct_;
    wire [15: 0] _immediate_;
    wire [25: 0] _nearaddr_;
    assign _rs_         = `UNKWIFN( _inst[25:21]
                            ,  5, isRType || isIType || isCType); // !isJType
    assign _rt_         = `UNKWIFN( _inst[20:16]
                            ,  5, isRType || isIType || isCType);
    assign _rd_         = `UNKWIFN( _inst[15:11]
                            ,  5, isRType || isCType);
    assign _shamt_      = `UNKWIFN( _inst[10:6 ]
                            ,  5, isRType);
    assign _funct_      = `UNKWIFN( _inst[ 5:0 ]
                            ,  6, isRType);
    assign _immediate_  = `UNKWIFN( _inst[15:0 ]
                            , 16, isIType);
    assign _nearaddr_   = `UNKWIFN( _inst[25:0 ]
                            , 26, isJType);

    // These characteristics could come from lookup table but this is more enlightening!
    wire isMemory, isMStore, isMLoad, isIComp;
    assign isMemory    = (_opcode_[5:4] == 2'b10____);
    assign isMLoad     = (_opcode_[5:3] == 3'b100___);
    assign isMStore    = (_opcode_[5:3] == 3'b101___);
    assign isIComp     = (_opcode_[5:3] == 3'b001___);
    wire #DD isISigned, isMSigned, isCopRead, isCopWrite;
    assign isISigned   = (isMemory || (isIComp && !_opcode_[2]));
    assign isMSigned   = (isMemory && !isMStore && !_opcode_[1] && !_opcode_[2]);
    assign isCopRead   = (isCType && (_rs_ == `OS_MFC0));
    assign isCopWrite  = (isCType && (_rs_ == `OS_MTC0));
    wire #DD isRShift, isRShiftI, isRShiftR, isROther;
    assign isRShift    = (isRType  && (_funct_[5:3] == 3'b000___));
    assign isRShiftI   = (isRShift && (_funct_[2]   ==    1'b0__));
    assign isRShiftR   = (isRShift && (_funct_[2]   ==    1'b1__));
    assign isROther    = (isRType  && (_funct_[5:4] == 2'b10____));
    wire isIJump;
    assign isIJump     = isJType;
    wire #DD isRJump, isJump, isJLink;
    assign isRJump     = (isRType  && (_funct_[5:1] == 5'b00100_));
    assign isJump      = (isIJump || isRJump);
    assign isJLink     = (isIJump && _opcode_[0]) || (isRJump && _funct_[0]); //JAL/JALR lo-bit==1
    wire #DD isBSimple, isBranchZo, isBranchZr, isBranchX, isBranch, isBranch0, isBLink;
    assign isBSimple   = (_opcode_[5:2] == 4'b0001__);
    assign isBranchZo  = (_opcode_[5:1] == 5'b00011_);
    assign isBranchZr  = (_opcode_      == 6'b000001);
    assign isBranchX   = (_opcode_[5:1] == 5'b00010_);
    assign isBranch    = (isBranchZr || isBSimple);
    assign isBranch0   = (isBranchZr || isBranchZo);
    assign isBLink     = (isBranchZr && _rt_[4]); //BGEZAL/BLTZAL (branch-and-link ops)
    wire isLink;
    assign isLink      = (isJLink || isBLink); //JALs & BALs

    assign IMMED    = _immediate_;
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
    assign DestReg  = (isJump || isBranch)
                        ? ( (isLink) // JUMP-LINK/BRANCH-LINK to $ra else $0
                            ? 5'd31
                            : 5'd0)
                        : ( (isRType)
                            ? _rd_
                            : ( (isMLoad || isIComp || isCopRead ) ? _rt_ : 5'd0)
                        );

    assign ISigned = isISigned, Jump = isJump, JR = isRJump, Branch = isBranch, Link = isLink,
            ALUSrcA = isRShiftI, ALUSrcB = (isMemory || isIComp),
            NEARADDR = {_nearaddr_,2'b00};
    assign CmpOp    = (isBSimple) //TODO: Flatten this into a casex
                        ? _opcode_[2:0]
                        : ( (isBranchZr)
                            ? (_opcode_[2:0] << _rt_[0]) //TODO: Simplify this! :(
                            : ((isJump) ? 3'b011 : 3'b000) //TODO: Use constant names!
                        );

endmodule
