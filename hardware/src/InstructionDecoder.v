module InstructionDecoder(
    input [31:0] inst,
    output [5:0] op,
    output [4:0] rs_base,
    output [4:0] rt_src2,
    output [4:0] rd,
    output [4:0] shamt,
    output [5:0] funct,

    output [25:0] target,
    output [15:0] immediate
);

	assign op      = inst[31:26];
	assign rs_base = inst[25:21];
	assign rt_src2 = inst[20:16];
	assign rd      = inst[15:11];
	assign shamt   = inst[10:6];
	assign funct   = inst[5:0];

    assign target =  inst[25:0];
	assign immediate = inst[15:0];

endmodule
