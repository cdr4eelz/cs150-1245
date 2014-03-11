module ImageBufferWriter #(
  parameter SCREEN_W = 800, SCREEN_H = 600)
(
  input         clock,
  input         reset,

  // Controller interface (potentially foreign clock-domain)
  input         scroll,           //Unsync'd, can get us out-of-count with vga source :(
  input         vga_enable,       //Slow-changing (except bounces), 1-flop sync
  input         start,            //2-cycle signal no-data, they request...
  output reg    start_ack,        //...we ack & edge-detect
  output reg    done,             //2-cycle signal no-data, we request...
  input         done_ack,         //...they ack

  // SRAM Arbiter Interface (RVA-style write-side of FIFO @clock)
  input         sram_ready,
  output        sram_valid,
  output [53:0] sram_dout,

  // VGA Interface (Start-Ack/Done-Ack lock-step & RVA video-data @clock)
  output reg    vga_start,        //2-cycle req/ack no-data
  input         vga_start_ack,
  input         vga_done,         //Unimplemented/redundant
  output reg    vga_done_ack,
  output        vga_video_ready,  //Unimplemented (always ready)! Worrisome!
  input         vga_video_valid,
  input  [ 7:0] vga_video);

localparam N_PIXEL = (SCREEN_W * SCREEN_H);
localparam MAX_ADDR = (N_PIXEL/4)-1;
localparam LAST_WORD = (SCREEN_W/4)-1;

assign vga_video_ready = 1'b1;

wire start_edge; // Simple edge dector on start condition

reg  vga_enable_r;
reg  [ 1:0] pixel_idx;
reg  [23:0] pixel_store;

wire vga_pixel_data_valid;
wire [31:0] vga_pixel_data;

assign vga_pixel_data_valid = (pixel_idx == 2'd3);
assign vga_pixel_data = {vga_video, pixel_store};

always @(posedge clock) begin
  if (reset) begin
    vga_enable_r <= 1'b0;
    pixel_idx <= 2'd0;
    vga_start <= 1'b0;
  end else begin
    if(start_edge)
      vga_enable_r <= vga_enable;

    if (vga_start && vga_start_ack)
      vga_start <= 1'b0;
    else if (start_edge)
      vga_start <= 1'b1;

    if(start_edge)
      pixel_idx <= 3'd0;
    else if (vga_video_valid)
      pixel_idx <= pixel_idx + 1;

    case (pixel_idx)
      2'd0: pixel_store[7:0]    <= vga_video;
      2'd1: pixel_store[15:8]   <= vga_video;
      2'd2: pixel_store[23:16]  <= vga_video;
    endcase
  end
end


reg  [16:0] addr;
reg  [ 7:0] video_words; //Column "X" across in 4-byte words
reg  [ 9:0] video_row;  //Row "Y" down
reg         frame;

// Generate Horizontal gradient of pixels
reg  [ 7:0] scroll_offset;
wire [31:0] pixel;
assign pixel = {scroll_offset + {video_words[5:0], 2'd3},
                scroll_offset + {video_words[5:0], 2'd2},
                scroll_offset + {video_words[5:0], 2'd1},
                scroll_offset + {video_words[5:0], 2'd0}};

// Concatenate mask, frame, addr, and pixel data
assign sram_dout = {4'hF, frame, addr, vga_enable_r ? vga_pixel_data : pixel};

assign sram_valid = vga_enable_r ? vga_pixel_data_valid : (addr <= MAX_ADDR);

wire inc; // Have a signal for when the output is incremented
assign inc = sram_valid && sram_ready;

reg start_ack_r;
assign start_edge = start_ack && ~start_ack_r;

always @(posedge clock) begin
  if(reset) begin
    addr <= MAX_ADDR+1;
    frame <= 1'b1;
    done <= 1'b0;
    start_ack <= 1'b0;
    start_ack_r <= 1'b0;
    video_words <= 8'd0;
    video_row <= 10'd0;
    scroll_offset <= 8'd0;
  end else begin
    if (done && done_ack)
      done <= 1'b0;
    else if ((addr == MAX_ADDR) && sram_ready) begin
      done <= 1'b1;

      // Since addr will be incremented, we avoid switching frames twice
      frame <= ~frame;

      // If selected, produce dynamic horizontal scrolling output
      if(scroll)
        scroll_offset <= scroll_offset + 1;
      else
        scroll_offset <= 8'd0;
    end

    // Synchronize start
    start_ack <= start;
    start_ack_r <= start_ack;

    // Use edge signal so we don't submit multiple at the same addr
    if (start_edge) begin
      addr <= 17'd0;
      video_words <= 8'd0;
      video_row <= 10'd0;
    end else if (inc) begin
      addr <= addr + 17'd1;
      if (video_words == LAST_WORD) begin
        video_words <= 8'd0;
        video_row <= video_row + 10'd1;
      end else
        video_words <= video_words + 1;
    end
  end
end

endmodule
