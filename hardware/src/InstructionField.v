
module InstructionField #(
	parameter strictMode = 0
)(
	input [31:0 ] _pc,
	input [ 5:0 ] _opcode,
	input [ 4:0 ] _rs,
	input [ 4:0 ] _rt,
	input [ 4:0 ] _rd,
	input [ 4:0 ] _shamt,
	input [ 5:0 ] _funct,
	input [15:0 ] _immediate,
	input [25:0 ] _target,
	
	output [ 5:0 ] IPCODE,
	output [ 4:0 ] BASE,
	output [ 4:0 ] DEST,
	output [15:0 ] SOFFSET,
	output [ 4:0 ] SRC,
	output [31:0 ] SIMMED,
	output [31:0 ] UIMMED,
	output [31:0 ] SHAMT,
	output [ 4:0 ] RSHAMT,
	output [ 4:0 ] SRC1,
	output [ 4:0 ] SRC2,
	output [31:0 ] PCTARGET,
	output [31:0 ] PCBRANCH,
	output [31:0 ] PCPLUS4,
	output [31:0 ] PCPLUS8
	
//	output [15:0 ] FAULT
);

function [31:0] SEXT16_32;
	input [15:0] in16;
	SEXT16_32 = {{16{in16[15]}}, in16};
endfunction

function [31:0] ZEXT16_32;
	input [15:0] in16;
	ZEXT16_32 = {16'b0, in16};
endfunction

	// These might later be reconstructed via bit-masks
    wire isRType, isMType, isIType, isRIType, isBGEZ, isBranch;
	assign isRType	= (_opcode == 6'b000000);
	assign isMType	= (_opcode[5] == 1'b1);
	assign isIType	= (_opcode[4] == 1'b1);
	assign isRIType	= (_funct[5] == 1'b1);
	assign isBGEZ	= (_opcode == 6'b000001);
	assign isBranch	= (_opcode[3:2] == 2'b01) || isBGEZ;
	
	// These all should become functions (like SEXT above)
	assign IPCODE	= (isRType) ? _funct : (isBGEZ) ? _rt : 'bx;
	assign BASE	= (isMType) ? _rs : 'bx;
	assign DEST	= (isMType || isIType) ? _rt : (isRType) ? _rd : 'bx;
	assign SOFFSET	= (isBranch) ? (SEXT16_32(_immediate) | 'b0) : 'bx;
	assign SRC	= _rs; // TODO: 
	assign SIMMED	= SEXT16_32(_immediate);
	assign UIMMED	= ZEXT16_32(_immediate);
	assign SHAMT	= _shamt; // TODO: 
	assign RSHAMT	= _rs; // TODO: 
	assign SRC1	= _rs; // TODO: 
	assign SRC2	= _rt; // TODO: 
	assign PCTARGET	= _pc | (_target << 2);
	assign PCBRANCH	= _pc + 4 + (SEXT16_32(_immediate) << 2); 
	assign PCPLUS4	= _pc + 4;
	assign PCPLUS8	= _pc + 8;

//	assign FAULT = 0; // Will identify blatantly unrecognized opcode/funct combinations & substitute NOP
	// If strictMode, FAULT will enforce zeros in spots that don't really matter (unused)
	// If simulating, drive outputs that must be unused to `bx.
	
	// XTRA: Could detect overflow or (bad ranges) of PC (Incoming and each potential PC output)
	// XTRA: Could detect mis-aligned PC...or arrange for pc to lack lower two bits (and only fault during branchs)!
	
endmodule
