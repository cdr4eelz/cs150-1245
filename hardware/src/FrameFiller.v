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
  output            ready,
  
  input [31:0] FF_frame_base    //NOTE: Require 8-byte alignment (32-byte ideally, maybe required)
  );

   //Your code goes here. GL HF DD DS
/*
//NOTE: DDR addressible to 64-bit "resolution", meaning lo 3-bits of address stripped.
//      Also, 4x64=256-bits are accessed at a time, so ideal alignment is 32-bytes (lo 5-bits zero)

//This approach imposes 16-byte alignment on the frame-buffer since it always sends
//  a pair of 8-byte values for each address AND uses the address to implicitly know
//  which of the pair is being sent.  In theory, the beginning & end of the frame-buffer
//  could be dealt with specially to get the alignment down to 4-bytes, and even the
//  "color" could be pre-shifted if one insisted on no byte-alignment (no need for that)!

//State ends up being implicit in the address which is currently 
localparam STATE_IDLE = 1'd0, STATE_RUNNING = 1'd1;

reg state; //Just an "isRunning" indicator
reg [31:0] addr;
reg [127:0] wdf_din,

wire isMemoryReady = !af_full && !wdf_full;
*/
  assign wdf_wr_en = 1'b0;
  assign af_wr_en  = 1'b0;
  assign ready     = 1'b1;

endmodule
