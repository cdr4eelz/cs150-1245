// UC Berkeley CS150
// Lab 3, Spring 2012
// Module: ALUdecoder
// Desc:   Sets the ALU operation
// Inputs: opcode: the top 6 bits of the instruction
//         funct: the funct, in the case of r-type instructions
// Outputs: ALUop: Selects the ALU's operation

`include "Opcode.vh"
`include "ALUop.vh"

module ALUdec(
  input [5:0] funct, opcode,
  output reg [3:0] ALUop
);

// ALU_ADDU,ALU_SUBU,ALU_SLT,ALU_SLTU,ALU_AND,ALU_OR,ALU_XOR,
// ALU_LUI,ALU_SLL,ALU_SRL,ALU_SRA,ALU_NOR,ALU_XXX
always @(*) begin
    ALUop = `ALU_XXX;
    case (opcode)
        // R-type (use funct)
        `RTYPE: begin case(funct)
            `SLL:   ALUop = `ALU_SLL;
            `SRL:   ALUop = `ALU_SRL;
            `SRA:   ALUop = `ALU_SRA;
            `SLLV:  ALUop = `ALU_SLL;
            `SRLV:  ALUop = `ALU_SRL;
            `SRAV:  ALUop = `ALU_SRA;
            `ADDU:  ALUop = `ALU_ADDU; // No "signed" add/sub,
            `SUBU:  ALUop = `ALU_SUBU; //   since no exceptions.
            `AND:   ALUop = `ALU_AND;
            `OR:    ALUop = `ALU_OR;
            `XOR:   ALUop = `ALU_XOR;
            `NOR:   ALUop = `ALU_NOR;
            `SLT:   ALUop = `ALU_SLT;
            `SLTU:  ALUop = `ALU_SLTU;
            `JR, `JALR: ALUop = `ALU_XXX;
            default: $display("Untrapped ALU op: funct=%h  @%t", funct, $time);
        endcase end

        // Load/store
        `LB, `LH, `LW, `LBU, `LHU, `SB, `SH, `SW:
            ALUop = `ALU_ADDU;

        // I-type
        `ADDIU: ALUop = `ALU_ADDU; //No ADDI (no exceptions)
        `SLTI:  ALUop = `ALU_SLT;
        `SLTIU: ALUop = `ALU_SLTU;
        `ANDI:  ALUop = `ALU_AND;
        `ORI:   ALUop = `ALU_OR;
        `XORI:  ALUop = `ALU_XOR;
        `LUI:   ALUop = `ALU_LUI;

        // Jump-types (don't use ALU)
        `J, `JAL, `BEQ, `BNE, `BLEZ, `BGTZ, `BLTZ: // See JUMP-R R-types above
            ALUop = `ALU_XXX;

        default:
            $display("Untrapped ALU op: opcode=%h  @%t", opcode, $time);
    endcase
end

endmodule
