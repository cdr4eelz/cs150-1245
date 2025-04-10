// UC Berkeley CS150
// Lab 3, Spring 2012
// Module: ALUdecoder
// Desc:   Sets the ALU operation
// Inputs: opcode: the top 6 bits of the instruction
//         funct: the funct, in the case of r-type instructions
// Outputs: ALUop: Selects the ALU's operation

`include "opcode.vh"
`include "aluop.vh"

module ALUdec(
  input wire [5:0] funct, opcode,
  output reg [3:0] ALUop
);

// ALU_ADDU,ALU_SUBU,ALU_SLT,ALU_SLTU,ALU_AND,ALU_OR,ALU_XOR,
// ALU_LUI,ALU_SLL,ALU_SRL,ALU_SRA,ALU_NOR,ALU_XXX
always @(*) begin
    ALUop = `ALU_XXX;
    case (opcode)
        // R-type (use funct)
        `OP_SPECIAL:
            begin case(funct)
                `OF_SLL:    ALUop = `ALU_SLL;
                `OF_SRL:    ALUop = `ALU_SRL;
                `OF_SRA:    ALUop = `ALU_SRA;
                `OF_SLLV:   ALUop = `ALU_SLL;
                `OF_SRLV:   ALUop = `ALU_SRL;
                `OF_SRAV:   ALUop = `ALU_SRA;
                `OF_ADD, //TODO: Overflow exception
                    `OF_ADDU:   ALUop = `ALU_ADDU;
                `OF_SUB, //TODO: Underflow exception
                    `OF_SUBU:   ALUop = `ALU_SUBU;
                `OF_AND:    ALUop = `ALU_AND;
                `OF_OR:     ALUop = `ALU_OR;
                `OF_XOR:    ALUop = `ALU_XOR;
                `OF_NOR:    ALUop = `ALU_NOR;
                `OF_SLT:    ALUop = `ALU_SLT;
                `OF_SLTU:   ALUop = `ALU_SLTU;
                //Known specials not activating ALU
                `OF_JR, `OF_JALR, `OF_SYSCALL, `OF_BREAK,
                    `OF_MFHI, `OF_MTHI, `OF_MFLO, `OF_MTLO,
                    `OF_MULT, `OF_MULTU, `OF_DIV, `OF_DIVU:
                        ALUop = `ALU_XXX;

//synthesis translate_off
                default:
                    $display("Untrapped ALU op: funct=%h  @%t", funct, $time);
//synthesis translate_on
            endcase end

        // Load/store
        `OP_LB, `OP_LH, `OP_LW, `OP_LBU, `OP_LHU, `OP_SB, `OP_SH, `OP_SW,
        `OP_LWL, `OP_LWR, `OP_SWL, `OP_SWR:
            ALUop = `ALU_ADDU;

        // I-type
        `OP_ADDI, //TODO: Overflow exception
            `OP_ADDIU: ALUop = `ALU_ADDU;
        `OP_SLTI:   ALUop = `ALU_SLT;
        `OP_SLTIU:  ALUop = `ALU_SLTU;
        `OP_ANDI:   ALUop = `ALU_AND;
        `OP_ORI:    ALUop = `ALU_OR;
        `OP_XORI:   ALUop = `ALU_XOR;
        `OP_LUI:    ALUop = `ALU_LUI;

        // Jump-types (See JUMP-R R-types above also)
        `OP_J, `OP_JAL, `OP_BEQ, `OP_BNE, `OP_BLEZ, `OP_BGTZ, `OP_REGIMM:
            ALUop = `ALU_XXX;   //These use a comparator rather than sharing ALU

//synthesis translate_off
        default:
            $display("Untrapped ALU op: opcode=%h  @%t", opcode, $time);
//synthesis translate_on
    endcase
end

endmodule
