
module InstructionControl #(
	parameter strictMode = 0
)(
	input [ 5:0 ] opcode,
	input [ 5:0 ] funct,
	input [ 4:0 ] rt,
	input [ 4:0 ] rd,

	output `BUS_IControl_type IControl_
//	output [15:0 ] FAULT
);

/*
ControlUnit DevinControl(
    .Opcode(opcode), .Funct(funct), .rd(rd), .rt_src2(rt),
    .MSigned(MSigned), .MemToReg(MemToReg), .MemWrite(MemWrite),
    .DataWidth(DataWidth), .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
    .Link(Link), .CmpOp(CmpOp), .JR(JR), .Jump(Jump),
    .DestReg(DestReg)
);
*/

    assign UNKNOWN = 'bx; // Can swap out for default value if unknown not desired
    
	// These characteristics could come from lookup table
	assign isRType	= (opcode == 6'b000000);
	assign isMType	= (opcode[5] == 1'b1);
	assign isMStore	= ((opcode[3] == 1'b1) && isMType);
	assign isMLoad  = (isMType && !isMStore);
	assign isIType	= (opcode[3] == 1'b1);
	assign isBSimple= (opcode[5:2] == 4'b0001);
	assign isBGELTZ	= (opcode == 6'b000001);
	assign isBranch	= (isBSimple || isBGELTZ);
	assign isIJump  = (opcode[5:1] == 5'b00001);
	assign isRJump  = (isRType && (funct[5:3] == 3'b001));
	assign isJump   = (isIJump || isRJump);
	
/*	output         MemToReg,
	output [ 4:0 ] DestReg,
	output         MemWrite,
	output [ 1:0 ] DataWidth,
	output         MSigned,
	output         ALUSrcA,
	output         ALUSrcB,
	output [ 3:0 ] ALUop,
	output         ISigned,
	
	output [ 2:0 ] CmpOp,
	output         Jump,
	output         JR,
	output         Link
*/
BUS_IControl_tun BUS_Icontrol
( ._BUS_(IControl_),
    .ISigned(
        (isMType || isIType) ? !opcode[2] : UNKNOWN
    ),
    .ALUSrcA(
        isRType && (opcode[5:2] == 0)
    ),
    .ALUSrcB(
        isMType || isIType
    ),
    
    .MemToReg(
        isMLoad
    ),
    .MemWrite(
        isMStore
    ),
    .DataWidth(
        (isMType) ? opcode[1:0] : 2'bx
    ),
    .MSigned(
        (isMType && !isMStore && !opcode[1]) ? !opcode[2] : 1'bx
    ),
    
    .Jump(
        isJump
    ),
    .Link(
        isJump
    ),
    .JR(
        (isIJump || isRJump) ? isRJump : 1'bx
    ),
    .CmpOp(
        (isBSimple) ? opcode[2:0] : ((isBGELTZ) ? opcode[2:0] << rt[0] : ((isJump) ? 3'b011 : 3'b000))
    ),
    .DestReg(
            (isJump? (opcode[0]? 5'b11111 : ((isRType&&funct[0])? rd : 5'b00000))
    	                          : (isRType? rd : ((isMLoad||isIType)? rt : 5'b00000)) )
    )
);

endmodule
