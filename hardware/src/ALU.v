`timescale 1ns / 1ps

// UC Berkeley CS150
// Lab 3, Spring 2012
// Module: ALU.v
// Desc:   32-bit ALU for the MIPS150 Processor
// Inputs: A: 32-bit value
// B: 32-bit value
// ALUop: Selects the ALU's operation 
// 						
// Outputs:
// Out: The chosen function mapped to A and B.

`include "Opcode.vh"
`include "ALUop.vh"

module ALU(
    input [31:0] A,B,
    input [3:0] ALUop,
    output reg [31:0] Out
);
	wire [4:0] shamt;
	assign shamt = A[4:0];
	
	always @(*) begin
		Out = 32'b0;
		
		case (ALUop)
		`ALU_ADDU:	Out =  $unsigned(A) + $unsigned(B);
		`ALU_SUBU:	Out =  $unsigned(A) - $unsigned(B);
		`ALU_SLT: 	Out = (  $signed(A) <   $signed(B)) ? 32'b01 : 32'b0;
		`ALU_SLTU:	Out = ($unsigned(A) < $unsigned(B)) ? 32'b01 : 32'b0;
		`ALU_AND:	Out = A & B;
		`ALU_OR:	Out = A | B;
		`ALU_XOR:	Out = A ^ B;
		`ALU_LUI:	Out = { B[15:0], 16'b0 };
		`ALU_SLL:	Out =           B  <<  shamt;
		`ALU_SRL:	Out = $unsigned(B) >>  shamt;
		`ALU_SRA:	Out =   $signed(B) >>> shamt;
		`ALU_NOR:	Out = ~A & ~B;
		`ALU_XXX:	Out = 32'bx;
		endcase
	end
endmodule
