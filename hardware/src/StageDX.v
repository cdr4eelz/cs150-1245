`include "CPUBusses.vh"

module StageDX(
    inout `BUS_CPUGlobal_type CPUGlobal,
    
    input  [31:0 ] PC,
    input  [31:0 ] INST,
    output [31:0 ] PCNext_,
    
    input  FWD_R1, FWD_R2,
    input  [31:0 ] FWD_RValue,
    input  [ 4:0 ] WBK_DestReg,
    input  [31:0 ] WBK_RegValue,
    
    output `BUS_IControl_type IControl_
    
/*
    output MemToReg_,
    output MemWrite_,
    output MSigned_,
    output Link_,
    output [ 1:0 ] DataWidth_,
    output [ 4:0 ] DestReg_,
    output [31:0 ] ALUOut_,
    output [31:0 ] R2Value_,
    output [31:0 ] PCPLUS8_
*/
);

    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

	wire [ 5:0 ] _opcode_;
	wire [ 4:0 ] _rs_, _rt_, _rd_, _shamt_;
	wire [ 5:0 ] _funct_;
	wire [15:0 ] _immediate_;
	wire [25:0 ] _target_;
	
	InstructionRange decodeRanges(
		.INST(INST),	// Pass in the instruction
		.opcode(_opcode_),				// Receive basic bit-ranges by "standard names"
		// These below are for internal use only (parsed immediately into fields)
		.rs(_rs_), .rt(_rt_), .rd(_rd_), .shamt(_shamt_),
		.funct(_funct_), .immediate(_immediate_), .target(_target_)
	);
	
	wire [ 5:0 ] IPCODE;
	wire [ 4:0 ] BASE, DEST, SRC, RSHAMT, SRC1, SRC2;
	wire [15:0 ] SOFFSET;
	wire [31:0 ] SIMMED, UIMMED, SHAMT;
	wire [31:0 ] PCTARGET, PCBRANCH, PCPLUS4, PCPLUS8;

	InstructionField decodeFields(
		._pc(PC), ._opcode(_opcode_),
		._rs(_rs_), ._rt(_rt_), ._rd(_rd_), ._shamt(_shamt_),
		._funct(_funct_), ._immediate(_immediate_), ._target(_target_),
		.IPCODE(IPCODE), .BASE(BASE), .DEST(DEST), .SOFFSET(SOFFSET),
		.SRC(SRC), .SIMMED(SIMMED), .UIMMED(UIMMED),
		.SHAMT(SHAMT), .RSHAMT(RSHAMT), .SRC1(SRC1), .SRC2(SRC2),
		.PCTARGET(PCTARGET), .PCBRANCH(PCBRANCH),
		.PCPLUS4(PCPLUS4), .PCPLUS8(PCPLUS8_)
	);
	
	wire ALUSrcA, ALUSrcB, Jump, JR;
	wire [ 2:0 ] CmpOp;
	
	InstructionControl decodeControl(
		.opcode(_opcode_), .rt(_rt_), .rd(_rd_), .funct(_funct_),
		.IControl_(IControl_)
/*		.MemToReg(MemToReg_), .MemWrite(MemWrite_),
		.DataWidth(DataWidth_), .MSigned(MSigned_),
		.Link(Link_), .ISigned(ISigned),
		.ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
		.DestReg(DestReg_), .Jump(Jump), .JR(JR), .CmpOp(CmpOp)
*/
	);
	
	wire ISigned_;
	BUS_IControl_tap BUS_IControl
	( ._BUS_(IControl_),
	   .ISigned(ISigned_)
	);
	
	// Piggyback on existing ALUDecoder from lab
	wire [ 3:0 ] ALUop;
	ALUdec ALUDecoder(
	    .opcode(_opcode_), .funct(_funct_),
	    .ALUop(ALUop)
	);
	
	wire [31:0 ] _rd1_, _rd2_;
	
    RegFile regfile(
        .clk(clk),
        .we(!stall),
        .ra1(SRC1),
        .ra2(SRC2),
        .wa(DestReg_M_),
        .wd(RegValue_M_),
        .rd1(_rd1_),
        .rd2(_rd2_)
    );
    
	wire [31:0 ] R1, R2, A, B, jumpPC;
    wire takeBranch, takeJump;
    
	assign R1 = (FWD_R1) ? FWD_RValue : _rd1_;
	assign R2 = (FWD_R2) ? FWD_RValue : _rd2_;
	assign R2Value_ = R2;
	assign A = (ALUSrcA) ? SHAMT : R1;
	assign B = (ALUSrcB) ? ((ISigned_) ? SIMMED : UIMMED) : R2;
    
	ALU alu(.A(A), .B(B), .ALUop(ALUop), .Out(ALUOut_));
    BranchCMP bcmp(.branchOp(CmpOp), .A(A), .B(B), .doBranch(takeBranch));

	assign jumpPC = (Jump ? (JR ? R1 : PCTARGET) : PCBRANCH);
	assign takeJump  = (Jump || takeBranch);
	assign NextPC = (takeJump) ? jumpPC : PCPLUS4;
	

endmodule
