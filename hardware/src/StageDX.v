`include "CPUBusses.vh"

module StageDX(
    inout `BUS_CPUGlobal_type CPUGlobal,
    
    input  [31: 0] PC,
    input  [31: 0] INST,
    output [31: 0] PCNext_,
    
    input  FWD_R1, FWD_R2,
    input  [31: 0] FWD_RValue,
    input  [ 4: 0] WBK_DestReg,
    input  [31: 0] WBK_RegValue,
    
    output `BUS_IControl_type IControl_,
    output [31: 0] ALUOut_,
    output [31: 0] R2Value_,
    output [31: 0] PCPLUS8_
);

    wire  clk, reset, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

	wire [ 5: 0] _opcode_;
	wire [ 4: 0] _rs_, _rt_, _rd_, _shamt_;
	wire [ 5: 0] _funct_;
	wire [15: 0] _immediate_;
	wire [25: 0] _target_;
	
	InstructionRange decodeRanges(
		.INST(INST),	// Pass in the instruction
		.opcode(_opcode_),				// Receive basic bit-ranges by "standard names"
		// These below are for internal use only (parsed immediately into fields)
		.rs(_rs_), .rt(_rt_), .rd(_rd_), .shamt(_shamt_),
		.funct(_funct_), .immediate(_immediate_), .target(_target_)
	);
	
	wire [ 5: 0] IPCODE;
	wire [ 4: 0] BASE, DEST, SRC, RSHAMT, SRC1, SRC2;
	wire [15: 0] SOFFSET;
	wire [31: 0] SIMMED, UIMMED, SHAMT;
	wire [31: 0] PCTARGET, PCBRANCH, PCPLUS4, PCPLUS8;

	InstructionField decodeFields(
		._pc(PC), ._opcode(_opcode_),
		._rs(_rs_), ._rt(_rt_), ._rd(_rd_), ._shamt(_shamt_),
		._funct(_funct_), ._immediate(_immediate_), ._target(_target_),
		.IPCODE(IPCODE), .BASE(BASE), .DEST(DEST), .SOFFSET(SOFFSET),
		.SRC(SRC), .SIMMED(SIMMED), .UIMMED(UIMMED),
		.SHAMT(SHAMT), .RSHAMT(RSHAMT), .SRC1(SRC1), .SRC2(SRC2),
		.PCTARGET(PCTARGET), .PCBRANCH(PCBRANCH),
		.PCPLUS4(PCPLUS4), .PCPLUS8(PCPLUS8)
	);
	
	InstructionControl decodeControl(
		.opcode(_opcode_), .rt(_rt_), .rd(_rd_), .funct(_funct_),
		.IControl_(IControl_)
	);
	
	// Tap only specific control signals used inside DX
	wire ISigned, Jump, JR, ALUSrcA, ALUSrcB;
	wire [ 2: 0] CmpOp;
	BUS_IControl_tap BUS_IControl
	( ._BUS_(IControl_),
	   .ISigned(ISigned), .Jump(Jump), .JR(JR), 
		.ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
		.CmpOp(CmpOp)
	);
	
	// Piggyback on existing ALUDecoder from lab
	wire [ 3: 0] ALUop;
	ALUdec ALUDecoder(
	    .opcode(_opcode_), .funct(_funct_),
	    .ALUop(ALUop)
	);
	
	wire [31: 0] _rd1_, _rd2_;
    RegFile regfile
    ( .clk(clk), .we(!stall),
        // Write-Back
        .wa(WBK_DestReg), .wd(WBK_RegValue),
        // Reading is asynchronous
        .ra1(SRC1), .ra2(SRC2),
        .rd1(_rd1_),.rd2(_rd2_)
    );
    
	wire [31: 0] R1, R2, A, B, jumpPC;
	assign R1 = (FWD_R1) ? FWD_RValue : _rd1_;
	assign R2 = (FWD_R2) ? FWD_RValue : _rd2_;
	assign A = (ALUSrcA) ? SHAMT : R1;
	assign B = (ALUSrcB) ? ((ISigned) ? SIMMED : UIMMED) : R2;
	assign jumpPC = (Jump ? (JR ? R1 : PCTARGET) : PCBRANCH);
    
    wire takeBranch, takeJump;
    BranchCMP bcmp
    ( .branchOp(CmpOp), .A(A), .B(B),
        .doBranch(takeBranch)
    );
	assign takeJump  = (Jump || takeBranch);

	ALU alu
	( .A(A), .B(B), .ALUop(ALUop),
	   .Out(ALUOut_)
	);
	assign PCNext_ = (takeJump) ? jumpPC : PCPLUS4;
	assign R2Value_ = R2;
    assign PCPLUS8_ = PCPLUS8;	

endmodule
