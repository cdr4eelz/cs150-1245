
module MIPS150(
    input clk, rst, stall,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);


StageWF wf
	(.clk(clk), .rst(rst), .stall(stall),
	.PCWF_(PCWF_), .PCNext_DX_(PCNext_DX_),
	.INST(INST)
	);
StageDX dx
	(.clk(clk), .rst(rst), .stall(stall),
	.PC_WF(PCWF_), .PCNext_DX_(PCNext_DX_)
	);
StageM  m
	(.clk(clk), .rst(rst), .stall(stall)
	);

iblk iblk
	(xyz);
dblk dblk
	(pdq);
uart uart
	(abc);


endmodule
    

