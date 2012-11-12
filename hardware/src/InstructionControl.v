`timescale 100ps / 1ps

`include "CPUBusses.vh"

module InstructionControl #(
	parameter strictMode = 0, NOUNKLE = 1
)(
	input [31:0 ] _inst,
	input [31:0 ] _pc,

	output `BUS_ICTL_type IControl_,
	
	output [ 5:0 ] IPCODE,
	output [ 4:0 ] DEST,
	output [15:0 ] SOFFSET,
	output [31:0 ] SIMMED,
	output [31:0 ] UIMMED,
	output [31:0 ] SHAMT,
	output [ 4:0 ] SRC1,
	output [ 4:0 ] SRC2,
	
	output [31:0 ] PCTARGET,
	output [31:0 ] PCBRANCH,
	output [31:0 ] PCPLUS4,
	output [31:0 ] PCPLUS8
	
//	output [15:0 ] FAULT
);
`define UNKNOWN 'bz // Can swap out for default value if unknown not desired
`define DEFAULT 'b0

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
    // Could use always and casex too
    assign isRType  = (_opcode_[5:0] == 6'b000000);
    assign isJType  = (_opcode_[5:1] == 5'b00001_);
    assign isIType  = (!isRType && !isJType);
    
    wire [ 4: 0] #1 _rs_, _rt_, _rd_, _shamt_;
    wire [ 5: 0] #1 _funct_;
    wire [15: 0] #1 _immediate_;
    wire [25: 0] #1 _target_;
    assign _rs_         = (!isJType || NOUNKLE) ? _inst[25:21] : 5`UNKNOWN;
    assign _rt_         = (!isJType || NOUNKLE) ? _inst[20:16] : 5`UNKNOWN;
    assign _rd_         = (isRType || NOUNKLE) ? _inst[15:11] : 5`UNKNOWN;
    assign _shamt_      = (isRType || NOUNKLE) ? _inst[10:6 ] : 5`UNKNOWN;
    assign _funct_      = (isRType || NOUNKLE) ? _inst[ 5:0 ] : 6`UNKNOWN;
    assign _immediate_  = (isIType || NOUNKLE) ? _inst[15:0 ] : 16`UNKNOWN;
    assign _target_     = (isJType || NOUNKLE) ? _inst[25:0 ] : 26`UNKNOWN;
    
    // Pre-computations for clarity (partly distilled out by logic simplification?)
	// These characteristics could come from lookup table
	wire #1 isMemory, isMStore, isMLoad;
	assign isMemory    = (_opcode_[5:4] == 2'b10);
	assign isMLoad     = (_opcode_[5:3] == 3'b100);
	assign isMStore    = (_opcode_[5:3] == 3'b101);
    wire #1 isIComp;
	assign isIComp     = (_opcode_[5:3] == 3'b001);
    wire #1 isRShift, isRShiftI, isRShiftR, isROther; 
	assign isRShift    = (isRType && (_funct_[5:3] == 3'b000));
	assign isRShiftI   = (isRShift && (_funct_[2] == 1'b0));
	assign isRShiftR   = (isRShift && (_funct_[2] == 1'b1));
	assign isROther    = (isRType && (_funct_[5:4] == 2'b10));
	wire #1 isJump, isRJump, isIJump;
	assign isRJump     = (isRType && (_funct_[5:3] == 3'b001));
	assign isIJump     = isJType;
	assign isJump      = (isIJump || isRJump);
	wire #1 isBSimple, isBGELTZ, isBranch, isBranchX, isBranch0;  
	assign isBSimple   = (_opcode_[5:2] == 4'b0001);
	assign isBGELTZ    = (_opcode_ == 6'b000001);
	assign isBranch    = (isBSimple || isBGELTZ);
	assign isBranchX   = (_opcode_[5:1] == 5'b00010);
	assign isBranch0   = (isBGELTZ || (_opcode_[5:1] == 5'b00011));
	
	assign IPCODE	= (isRType) ? _funct_ : (isBGELTZ || NOUNKLE) ? _rt_ : 6`UNKNOWN;
	assign DEST	    = (isRType) ? _rd_ : (isMLoad || isIComp) ? _rt_ : 5'd0;
	assign SOFFSET	= (isMemory || NOUNKLE) ? (SEXT16_32(_immediate_)) : 32`UNKNOWN;
	assign SIMMED	= SEXT16_32(_immediate_);
	assign UIMMED	= ZEXT16_32(_immediate_);
	assign SHAMT	= (isRShiftI || NOUNKLE) ? _shamt_ : 5`UNKNOWN; 
	assign SRC1     = ((!isJType && !isRShiftI) || NOUNKLE) ? _rs_ : 5`UNKNOWN; 
	assign SRC2     = (isBranch0) ? 5'd0 : 
	                   (isROther || isBranchX || isRShift || isMStore || NOUNKLE)
	                       ? _rt_ : 5`UNKNOWN;  
	
	assign PCTARGET	= (isIJump || NOUNKLE) ? {_pc[31:28], _target_, 2'b00} : 32`UNKNOWN;
	assign PCBRANCH	= (isBranch || NOUNKLE) ? (_pc + 4 + (SEXT16_32(_immediate_) << 2)) : 32`UNKNOWN;
	assign PCPLUS4	= _pc + 4;
	assign PCPLUS8	= _pc + 8;
	
	// Embed existing ALUDecoder from lab
	wire [ 3: 0] #1 ALUop;
	ALUdec ALUDecoder(
	    .opcode(_opcode_), .funct(_funct_),
	    .ALUop(ALUop)
	);
    
	`BUS_ICTL_type delayIControl;
	assign #1 IControl_ = delayIControl;
    BUS_ICTL_tun BUS_ICTL
    ( ._BUS_(delayIControl),
        .ISigned(
            (isMemory) ? 1'b1 : (isIComp) ? !_opcode_[2] : 1`DEFAULT //TODO: Move to isXYZ
        ),
        .ALUsrcA(
            isRShiftI
        ),
        .ALUsrcB(
            isMemory || isIComp
        ),
        .ALUop(ALUop),
        
        .MemToReg(
            isMLoad
        ),
        .MemWrite(
            isMStore
        ),
        .DataWidth(
            (isMemory) ? _opcode_[1:0] : 2`DEFAULT
        ),
        .MSigned(
            (isMemory && !isMStore && !_opcode_[1]) ? !_opcode_[2] : 1`DEFAULT
        ),
        
        .Jump(
            isJump
        ),
        .Link(
            isJump
        ),
        .JR(
            (isIJump || isRJump) ? isRJump : 1'bz
        ),
        .CmpOp(
            (isBSimple) ? _opcode_[2:0] : ((isBGELTZ) ? _opcode_[2:0] << _rt_[0] : ((isJump) ? 3'b011 : 3'b000))
        ),
        .DestReg(
                (isJump? (_opcode_[0]? 5'b11111 : ((isRType&&_funct_[0])? _rd_ : 5'b00000))
                                      : (isRType? _rd_ : ((isMLoad||isIComp)? _rt_ : 5'b00000)) )
        )
    );
    
endmodule
