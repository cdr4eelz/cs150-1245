`include "CPUGlobal.vh"

module InstructionControl #(
    parameter DD=`COLT45_DD
)(
    input [31:0 ] _inst,
    input [31:0 ] _pc,

    output `BUS_ICTL_type IControl_,

    output [31:0 ] SIMMED,
    output [31:0 ] UIMMED,
    output [31:0 ] SHAMT,
    output [ 4:0 ] SRC1,
    output [ 4:0 ] SRC2,

    output [31:0 ] PCTARGET,
    output [31:0 ] PCBRANCH

//  output [15:0 ] FAULT
);


    function [31:0] SEXT16_32;
        input [15:0] in16;
        SEXT16_32 = {{16{in16[15]}}, in16};
    endfunction

    function [31:0] ZEXT16_32;
        input [15:0] in16;
        ZEXT16_32 = {16'b0, in16};
    endfunction

    wire [ 5: 0] _opcode_ = _inst[31:26];
    wire isRType, isIType, isJType;

    assign isRType  = (_opcode_[5:0] == 6'b000000);
    assign isJType  = (_opcode_[5:1] == 5'b00001_);
    assign isIType  = (!isRType && !isJType);

    //TODO: Utilize the `TVALID(valid-expr,value) optional concat/unknown trick
    wire [ 4: 0] _rs_, _rt_, _rd_, _shamt_;
    wire [ 5: 0] _funct_;
    wire [15: 0] _immediate_;
    wire [25: 0] _nearaddr_;
    assign _rs_         = (isRType || isIType) ? _inst[25:21] : `UNKNOWN(5); // !isJType
    assign _rt_         = (isRType || isIType) ? _inst[20:16] : `UNKNOWN(5);
    assign _rd_         = (isRType) ? _inst[15:11] : `UNKNOWN(5);
    assign _shamt_      = (isRType) ? _inst[10:6 ] : `UNKNOWN(5);
    assign _funct_      = (isRType) ? _inst[ 5:0 ] : `UNKNOWN(6);
    assign _immediate_  = (isIType) ? _inst[15:0 ] : `UNKNOWN(16);
    assign _nearaddr_   = (isJType) ? _inst[25:0 ] : `UNKNOWN(26);

    // Pre-computations for clarity (partly distilled out by logic simplification?)
    // These characteristics could come from lookup table
    wire #DD isMemory, isMStore, isMLoad, isIComp, isISigned, isMSigned;
    assign isMemory    = (_opcode_[5:4] == 2'b10);
    assign isMLoad     = (_opcode_[5:3] == 3'b100);
    assign isMStore    = (_opcode_[5:3] == 3'b101);
    assign isIComp     = (_opcode_[5:3] == 3'b001);
    assign isISigned   = (isMemory || (isIComp && !_opcode_[2]));
    assign isMSigned   = (isMemory && !isMStore && !_opcode_[1] && !_opcode_[2]);
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

//  assign IPCODE   = (isRType) ? _funct_ : (isBGELTZ) ? _rt_ : `UNKNOWN(6);
//  assign SOFFSET  = (isMemory) ? (SEXT16_32(_immediate_)) : `UNKNOWN(32);
    assign SIMMED   = SEXT16_32(_immediate_);
    assign UIMMED   = ZEXT16_32(_immediate_);
    assign SHAMT    = (isRShiftI) ? _shamt_ : `UNKNOWN(5);
    assign SRC1     = (!isJType && !isRShiftI) ? _rs_ : 5'd0;
    assign SRC2     = (isBranch0) ? 5'd0 :
                       (isROther || isBranchX || isRShift || isMStore)
                           ? _rt_ : 5'd0;

    assign PCTARGET = (isIJump) ? {_pc[31:28], _nearaddr_, 2'b00} : `UNKNOWN(32);
    assign PCBRANCH = (isBranch) ? (_pc + 4 + (SEXT16_32(_immediate_) << 2)) : `UNKNOWN(32);

    // Embed existing ALUDecoder from lab
    wire [ 3: 0] #DD ALUop;
    ALUdec ALUDecoder(
        .opcode(_opcode_), .funct(_funct_),
        .ALUop(ALUop)
    );

    wire [1:0] MemShift = (isMemory)
                        ? (~_opcode_[1:0]) // ~x == 3-x, like 1's complement!
                        : `UNKNOWN(2);
    wire [2:0] CmpOp    = (isBSimple)
                        ? _opcode_[2:0]
                        : ( (isBGELTZ)
                            ? (_opcode_[2:0] << _rt_[0]) //TODO: Strange formula :(
                            : ((isJump) ? 3'b011 : 3'b000) //TODO: Use constant names!
                        );
    wire [4:0] DestReg  = (isJump)
                        ? ( (isLink) // JUMP-LINK to $ra else $0
                            ? 5'd31
                            : 5'd0)
                        : ( (isRType)
                            ? _rd_
                            : ((isMLoad || isIComp) ? _rt_ : 5'd0)
                        );

    `BUS_ICTL_type delayIControl;
    assign #DD IControl_ = delayIControl;
    BUS_ICTL_tun BUS_ICTL
    ( ._BUS_(delayIControl),
        .ISigned( isISigned ), .MSigned( isMSigned ), .DestReg( DestReg ),
        .MemToReg( isMLoad ), .MemWrite( isMStore ), .MemShift( MemShift ),
        .ALUOp( ALUop ), .ALUSrcA( isRShiftI ), .ALUSrcB( isMemory || isIComp ),
        .Jump( isJump ), .JR( isRJump ), .Link( isLink ), .CmpOp( CmpOp )
    );

endmodule
