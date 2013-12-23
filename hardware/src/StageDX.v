`include "cpuglobal.vh"

module StageDX(
    input clk, rst, stall,

    // Asynchronous plugs to shared outer components
    output [ 4: 0] REG_R1_, REG_R2_,
    input  [31: 0] REG_D1_, REG_D2_,
    output         CopInHot,
    output [ 4: 0] CopAddr,
    input  [31: 0] CopOut,

    // Prior stage inputs
    input  [31: 0] _PC,
    input  [31: 0] _INST,

    // Outputs (decode / generic instruction cascade)
    output `BUS_ICTL_type IControl_,

    // Outputs (Execute related computations)
    output [31: 0] MemAddr_,
    output [31: 0] MemWValue_,
    output [31: 0] RegWValue_,
    output [31: 0] PCBranch_,
    output         DOBranch_
);

    // Decoded signals only used locally
    wire [ 4: 0] SRC1, SRC2;
    wire [31: 0] SIMMED, UIMMED, SHAMT, PCTARGET, PCBRANCH;
    wire COPREAD; //ISR//

    // Asyncronous drive/read of outer register/coprocessor components
    assign  REG_R1_ = SRC1,     REG_R2_ = SRC2;
    wire [31: 0] R1 = REG_D1_,  R2      = REG_D2_; // Redeclare to clarify dependencies...
    // SEE: CopAddr & CopOut (for asynchronous drives)

    InstructionControl decodeControl(
        ._pc(_PC), ._inst(_INST),

        .IControl_(IControl_),

        .SIMMED(SIMMED), .UIMMED(UIMMED),
        .SHAMT(SHAMT), .SRC1(SRC1), .SRC2(SRC2),
        .PCTARGET(PCTARGET), .PCBRANCH(PCBRANCH),
        .COPREAD(COPREAD), .COPWRITE(CopInHot), .COPADDR(CopAddr) //ISR//
    );

    // Tap control signals used inside DX
    wire ALUSrcA, ALUSrcB, ISigned, Jump, JR, Link;
    wire [ 3: 0] ALUOp;
    wire [ 2: 0] CmpOp;
    BUS_ICTL_tap BUS_ICTL
    ( ._BUS_(IControl_), // Unused (explicitly listed to make warnings meaningful)
        .ALUOp(ALUOp), .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ISigned(ISigned), .CmpOp(CmpOp), .Jump(Jump), .JR(JR), .Link(Link),
        .MemToReg(),.DestReg(),.MemWrite(),.MemShift(),.MSigned()
    );

    wire [31: 0] ALUResult;
    ALU alu
    ( .ALUop(ALUOp),
        .A( (ALUSrcA) ? SHAMT : R1 ),
        .B( (ALUSrcB) ? ((ISigned) ? SIMMED : UIMMED) : R2 ),
        .Out(ALUResult)
    );

    wire takeBranch;
    BranchCMP bcmp
    ( .branchOp(CmpOp),
        .A(R1), .B(R2), // Always pull from register/forward output
        .doBranch(takeBranch)
    );

//TODO: Good spot for `UNKNOWN
    assign DOBranch_    = (Jump || takeBranch);
    assign PCBranch_    = (Jump) ? (JR ? R1 : PCTARGET) : PCBRANCH;
    assign MemAddr_     = ALUResult;
    assign MemWValue_   = R2;
    assign RegWValue_   = (Link) ? (_PC+8) //$ra := PC+8 because of trailing instruction
                                : ( (COPREAD) ? CopOut : ALUResult );

endmodule
