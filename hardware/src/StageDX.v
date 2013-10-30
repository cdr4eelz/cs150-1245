`include "CPUBusses.vh"

module StageDX(
//  input `BUS_CPUGlobal_type CPUGlobal, // Unused!
    // Asynchronous plugs to shared outer components
    output [ 4: 0] REG_R1_, REG_R2_,
    input  [31: 0] REG_D1_, REG_D2_,

    // Prior stage inputs
    input  [31: 0] _PC,
    input  [31: 0] _INST,

    // Outputs (decode / generic instruction cascade)
    output `BUS_ICTL_type IControl_,
    output [31: 0] PCPLUS8_,

    // Outputs (Execute related computations)
    output [31: 0] MemAddr_,
    output [31: 0] MemWValue_,
    output [31: 0] RegWValue_,
    output [31: 0] PCBranch_,
    output         DOBranch_
);

    wire [ 5: 0] #1 IPCODE;
    wire [ 4: 0] #1 DEST, SRC1, SRC2;
    wire [15: 0] #1 SOFFSET;
    wire [31: 0] #1 SIMMED, UIMMED, SHAMT;
    wire [31: 0] #1 PCTARGET, PCBRANCH, PCPLUS4, PCPLUS8;

    InstructionControl decodeControl(
        ._pc(_PC), ._inst(_INST),

        .IControl_(IControl_),

        .IPCODE(IPCODE), .DEST(DEST), .SOFFSET(SOFFSET),
        .SIMMED(SIMMED), .UIMMED(UIMMED),
        .SHAMT(SHAMT), .SRC1(SRC1), .SRC2(SRC2),
        .PCTARGET(PCTARGET), .PCBRANCH(PCBRANCH),
        .PCPLUS4(PCPLUS4), .PCPLUS8(PCPLUS8)
    );

    // Asyncronously plug into outer register component
    assign  REG_R1_ = SRC1,     REG_R2_ = SRC2;
    wire [31: 0] R1 = REG_D1_,  R2      = REG_D2_; // Redeclare to clarify dependencies

    // Tap only specific control signals used inside DX
    wire ISigned, Jump, JR, ALUSrcA, ALUSrcB;
    wire [ 3: 0] ALUOp;
    wire [ 2: 0] CmpOp;
    BUS_ICTL_tap BUS_ICTL
    ( ._BUS_(IControl_), // Unused (explicitly listed to make warnings meaningful)
        .ALUOp(ALUOp), .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ISigned(ISigned), .CmpOp(CmpOp), .Jump(Jump), .JR(JR),
        .MemToReg(),.DestReg(),.MemWrite(),.DataWidth(),.MSigned(),.Link()
    );

    wire [31: 0] #1 A, B, ALUResult;
    assign A = (ALUSrcA) ? SHAMT : R1;
    assign B = (ALUSrcB) ? ((ISigned) ? SIMMED : UIMMED) : R2;
    ALU alu
    ( .ALUop(ALUOp),
        .A(A), .B(B),
        .Out(ALUResult)
    );

    wire #1 takeBranch;
    BranchCMP bcmp
    ( .branchOp(CmpOp),
        .A(R1), .B(R2), // Always pull from register/forward output
        .doBranch(takeBranch)
    );

    assign DOBranch_    = (Jump || takeBranch);
    assign PCBranch_    = (Jump ? (JR ? R1 : PCTARGET) : PCBRANCH);
    assign MemAddr_     = ALUResult;
    assign MemWValue_   = R2;
    assign RegWValue_   = ALUResult;
    assign PCPLUS8_     = PCPLUS8;

endmodule
