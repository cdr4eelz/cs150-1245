module FrameFiller(//system:
  input             clk,
  input             rst,
  // fill control:
  input             valid,
  input [23:0]      color,
  // ddr2 fifo control:
  input             af_full,
  input             wdf_full,
  // ddr2 fifo outputs:
  output [127:0]    wdf_din,
  output            wdf_wr_en,
  output [30:0]     af_addr_din,
  output            af_wr_en,
  output [15:0]     wdf_mask_din,
  // handshaking:
  output            ready);


  // Remove these when you implement the frame filler:
  assign wdf_wr_en = 1'b0;
  assign af_wr_en  = 1'b0;
  assign ready     = 1'b1;





endmodule
