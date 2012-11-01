module InstructionRange #(
	parameter strictMode = 0
)(
	input  [31:0 ] INST,

	output [ 5:0 ] opcode,
	output [ 4:0 ] rs,
	output [ 4:0 ] rt,
	output [ 4:0 ] rd,
	output [ 4:0 ] shamt,
	output [ 5:0 ] funct,
	output [15:0 ] immediate,
	output [25:0 ] target
	
//	output [15:0 ] FAULT
);
	
	assign #1 opcode      = INST[31:26];
	assign rs          = INST[25:21];
	assign rt          = INST[20:16];
	assign rd          = INST[15:11];
	assign shamt       = INST[10:6 ];
	assign funct       = INST[ 5:0 ];
	assign immediate   = INST[15:0 ];
	assign target      = INST[25:0 ];

//	assign FAULT = 0; // Will identify blatantly unrecognized opcodes & substitute NOP
	// If strictMode, FAULT will enforce zeros in spots that don't really matter (unused)
	// If simulating, drive outputs that must be unused to `bx.
	
endmodule
