
module MIPS150(
    input clk, rst, stall,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

`include "CPUBusses.vh"
wire [ 2:0 ] CRS = {clk,rst,stall};


StageWF s_WF
	(.CRS(CRS),
	.PCWF_(PCWF_), .PCNext_DX_(PCNext_DX_),
	.INST(INST)
	);
	
StageDX s_DX
	(.CRS(CRS),
	.PC_WF(PCWF_), .PCNext_DX_(PCNext_DX_)
	);
	
StageM  s_M
	(.CRS(CRS)
	);

dmem_blk_ram mem_DATA(
		clka,
		ena,
		wea,
		addra,
		dina,
		douta);

UART uart
    (.Clock(clk), .Reset(rst),
    .SIn(FPGA_SERIAL_RX), .SOout(FPGA_SERIAL_TX)
    );
    
/*	
	  input   [7:0] DataIn,
	  input         DataInValid,
	  output        DataInReady,
	
	  output  [7:0] DataOut,
	  output        DataOutValid,
	  input         DataOutReady,
	);
*/

endmodule
    

