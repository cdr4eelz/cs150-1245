`include "CPUBusses.vh"

module StageDX(
    inout `BUS_CPUGlobal_type CPUGlobal,    // CURRENTLY UNUSED!
    // Asynchronous plugs to shared outer components
    output [ 4: 0] REG_R1_,     REG_R2_,
    input  [31: 0] REG_D1_,     REG_D2_,
    
    // Prior stage inputs
    input  [31: 0] PC,
    input  [31: 0] INST,
    
    // Outputs (decode/ generic instruction cascade)
    output `BUS_ICTL_type IControl_,
    output [31: 0] PCPLUS8_,
    
    // Outputs (Execute related computations)
    output [31: 0] ALUOut_,
    output [31: 0] R2Value_,
    output [31: 0] PCNext_
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
	
	InstructionControl decodeControl(
		.opcode(_opcode_), .rt(_rt_), .rd(_rd_), .funct(_funct_),
		.IControl_(IControl_)
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
	
	// Asyncronously plug into outer register component
	wire [31: 0] R1, R2;   // Declare here to clarify dependencies
	assign REG_R1_ = SRC1,     R1 = REG_D1_;
	assign REG_R2_ = SRC2,     R2 = REG_D2_;
	
	// Tap only specific control signals used inside DX
	wire ISigned, Jump, JR, ALUsrcA, ALUsrcB;
	wire [ 3: 0] ALUop;
	wire [ 2: 0] CmpOp;
	BUS_ICTL_tap BUS_ICTL
	( ._BUS_(IControl_),
        .ALUsrcA(ALUsrcA),  .ALUsrcB(ALUsrcB),  .ALUop(ALUop),
        .ISigned(ISigned),  .CmpOp(CmpOp),      .Jump(Jump),    .JR(JR), 
        // Unused (explicitly listed to make warnings meaningful)
        .MemToReg(),.DestReg(),.MemWrite(),.DataWidth(),.MSigned(),.Link()
	);
	
	wire [31: 0] A, B, jumpPC;
	assign A = (ALUsrcA) ? SHAMT : R1;
	assign B = (ALUsrcB) ? ((ISigned) ? SIMMED : UIMMED) : R2;
	assign jumpPC = (Jump ? (JR ? R1 : PCTARGET) : PCBRANCH);
    
    wire takeBranch, takeJump;
    BranchCMP bcmp
    ( .branchOp(CmpOp), .A(A), .B(B),
        .doBranch(takeBranch)
    );
	assign takeJump  = (Jump || takeBranch); // Jump should use CmpOp
    
	ALU alu
	( .A(A), .B(B), .ALUop(ALUop),
	   .Out(ALUOut_)
	);
	assign PCNext_ = (takeJump) ? jumpPC : PCPLUS4;
	assign R2Value_ = R2;
    assign PCPLUS8_ = PCPLUS8;	
    
endmodule
