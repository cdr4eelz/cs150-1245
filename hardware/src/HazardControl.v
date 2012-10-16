module HazardControl(
    input [4:0] DestReg_M_,
    input [4:0] SrcReg1DX_,
    input [4:0] SrcReg2DX_,
    output HForward1, HForward2
);

	assign HForward1 = (DestReg_M_ == SrcReg1DX_) && (DestReg_M_ != 0);
	assign HForward2 = (DestReg_M_ == SrcReg2DX_) && (DestReg_M_ != 0);

endmodule
