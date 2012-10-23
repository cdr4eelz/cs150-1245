
module MIPS150
(
    input clk, rst, stall,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

`define BUS_CPUGlobal_type wire[2:0]
`BUS_CPUGlobal_type CPUGlobal;
BUS_CPUGlobal_module BUS_CPUGlobal
( .BUS(CPUGlobal),
    .CLK(clk), .RST(rst), .STL(stall)
);


wire [31:0 ] PCWF_;
wire [31:0 ] INSTWF_;
StageWF s_WF
(   .CPUGlobal(CPUGlobal),
    .IMEM_read_addr(IMEM_addrb), .IMEM_read_data(IMEM_doutb),

    .PCNext(PCNext_DX_),

	.PC(PCWF_), .INST(INSTWF_)
);

wire [31:0 ] PC_DX   = PCWF_;   // Is registered for us in prior stage
wire [31:0 ] INST_DX = INSTWF_; //      "
StageDX s_DX
(   .CPUGlobal(CPUGlobal),

	.PC(PC_DX), .INST(INST_DX),
	
	.PCNext(PCNext_DX_)
);

StageM  s_M
(      .CPUGlobal(CPUGlobal)

);


dmem_blk_ram DMEM
(   .clka(clk),               // Clocks of a feather
		.ena(DMEM_ena), .addra(DMEM_addra),   // One DMEM port...
		.douta(DMEM_douta),                   //  for data read...
		.dina(DMEM_dina), .wea(DMEM_wea)      //  & data write
);

imem_blk_ram IMEM
(   .clka(clk), .clkb(clk),    // Clocks of a feather
		.ena(IMEM_), .addra(IMEM_addra),      // Separate IMEM port...
		.dina(IMEM_dina), .wea(IMEM_wea),     //  for inst write...
		                                      // ...VS...
		.addrb(IMEM_addrb), .doutb(IMEM_doutb)//  inst fletch
);

UART uart
    (.Clock(clk), .Reset(rst),  // Clocks of a feather
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
    

