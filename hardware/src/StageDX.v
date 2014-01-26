`include "cpuglobal.vh"

module StageDX(
//NOTE:Currently just asynchronous "control" logic!
//    input clk, rst, stall,

    // Asynchronous plugs to shared outer components
    output [ 4: 0] REG_R1_, REG_R2_, CopAddr,
    input  [31: 0] REG_D1_, REG_D2_, CopOut,
    output         CopInHot,

    // Prior stage inputs
    input  [31: 0] _PC,
    input  [31: 0] _INST,

    // Global control signals
    output [ 4: 0] DestReg_,
    output [ 1: 0] MemShift_,
    output         MemToReg_, MemWrite_, MemSigned_,

    // Outputs (Execute related computations)
    output [31: 0] MemAddr_,
    output [31: 0] MemWValue_,
    output [31: 0] RegWValue_,

    // Feedback to prior stages (branching)
    output [31: 0] PCBranch_,
    output         DOBranch_
);

//TODO: Avoid extra adders by passing pre-added PC value and/or sharing ALU

    // Decoded signals used locally in DX
    wire [31: 0] SIMMED, UIMMED;
    wire [27: 0] NEARADDR;
    wire [ 4: 0] SRC1, SRC2, SHAMT;
    wire ALUSrcA, ALUSrcB, ISigned, Jump, JR, Link, COPREAD;
    wire [ 3: 0] ALUOp;
    wire [ 2: 0] CmpOp;

    // Asyncronous drive/read of outer register/coprocessor components
    assign  REG_R1_ = SRC1,     REG_R2_ = SRC2;
    wire [31: 0] R1 = REG_D1_,  R2      = REG_D2_; // Redeclare to clarify dependencies...
    //NOTE:CopAddr & CopOut are also asynchronous drives

    InstructionControl decodeControl(
        ._inst(_INST),
        // Global control signals
        .DestReg(DestReg_), .MemShift(MemShift_),
        .MemToReg(MemToReg_), .MemWrite(MemWrite_),
        .MemSigned(MemSigned_),
        // Standard control signals only used locally
        .ALUOp(ALUOp), .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ISigned(ISigned), .CmpOp(CmpOp), .Jump(Jump), .JR(JR), .Link(Link),
        // Locally used special values
        .SIMMED(SIMMED), .UIMMED(UIMMED), .NEARADDR(NEARADDR),
        .SRC1(SRC1), .SRC2(SRC2), .COPWRITE(CopInHot), .COPADDR(CopAddr),
        .SHAMT(SHAMT), .COPREAD(COPREAD)
    );

    wire [31: 0] ALUResult;
    ALU alu
    ( .ALUop(ALUOp),
        .A( (ALUSrcA) ? {27'd0, SHAMT} : R1 ),
        .B( (ALUSrcB) ? ((ISigned) ? SIMMED : UIMMED) : R2 ),
        .Out(ALUResult)
    );

    wire takeBranch;
    BranchCMP bcmp
    ( .branchOp(CmpOp),
        .A(R1), .B(R2), // Always pull from register/forward output
        .doBranch(takeBranch)
    );

    // PC adders and helper values
    wire [31: 0] PCTARGET, PCBRANCH, LINKADDR;
    assign PCTARGET = {_PC[31:28], NEARADDR};
    assign PCBRANCH = (_PC+4) + (SIMMED << 2); //TODO: Simplify ADDER (and more explicit)
    assign LINKADDR = (_PC+8); //$ra := PC+8 because of trailing instruction

    // Stage results (other than control signals passed through)
    assign DOBranch_    = (Jump || takeBranch); //NOTE: Relies on CmpOp to suppress takeBranch
    assign PCBranch_    = (Jump) ? (JR ? R1 : PCTARGET) : PCBRANCH;
    assign MemAddr_     = ALUResult;
    assign MemWValue_   = R2;
    assign RegWValue_   = (Link) ? LINKADDR : ( (COPREAD) ? CopOut : ALUResult );

endmodule
