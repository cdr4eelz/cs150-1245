//`define MACROSAFE // required to get this to compile in MODELSIM...
//`include "Const.v"
`ifndef max
`define max(x,y)    ((x) > (y) ? (x) : (y))
`endif
`ifndef min
`define min(x,y)    ((x) < (y) ? (x) : (y))
`endif

module StaticImage #(
  parameter [12:0] SCREEN_W = 800, SCREEN_H = 600,
  parameter [12:0]    IMG_W = 200,    IMG_H = 150,
  parameter [ 2:0] SCALE = 1) //*1:200x150 *2:400x300 *3:600x450 *4:800x600
(
  input         clock,
  input         reset,

  input         start,
  output reg    start_ack,
  output reg    done,       //Unimplemented/redundant
  input         done_ack,

  input         video_ready,
  output        video_valid,
  output [23:0] video_rgb,
  output [ 7:0] video_gray);


// Helpful pre-calculation complicated by simple scaling
localparam
  SMG_W  = `min( (IMG_W * SCALE),         SCREEN_W),
  SMG_H  = `min( (IMG_H * SCALE),         SCREEN_H),
  IMG_SX = `max( (SCREEN_W - SMG_W) / 2,         0),
  IMG_SY = `max( (SCREEN_H - SMG_H) / 2,         0),
  IMG_PX = `min( (IMG_SX + SMG_W),        SCREEN_W),
  IMG_PY = `min( (IMG_SY + SMG_H),        SCREEN_H);
//IMG_N_PIXEL   = (SMG_W  * SMG_H);
localparam [12:0] SUB_SWIDTH = (IMG_W-1);
localparam [ 2:0] SUB_SCALE = (SCALE-1);


// Start-Ack(Done-Ack) Signal Management
reg  start_ack_r = 1'b0;
wire start_edge = start_ack_r && ~start_ack;

always @(posedge clock) begin
  if (reset) begin
    {start_ack, start_ack_r, done} <= 0;
  end else begin
    {start_ack, start_ack_r} <= {start, start_ack};
  end
end


// Standard Row/Col Feed Count & Identify Active Image Area
reg  [12:0] img_row, img_col;
wire col_active, row_active, pxl_active, video_adv;

assign col_active = ((img_col > (IMG_SX-1)) || (IMG_SX == 0)    )
                 && ((img_col <  IMG_PX   ) || (IMG_PX >= SCREEN_W));
assign row_active = ((img_row > (IMG_SY-1)) || (IMG_SY == 0)    )
                 && ((img_row <  IMG_PY   ) || (IMG_PY >= SCREEN_H));
assign pxl_active = row_active && col_active;
assign video_adv = video_valid && video_ready;

always @(posedge clock) begin
  if (reset) begin
    img_row <= SCREEN_H; //Indirectly disables output
    img_col <= SCREEN_W;
  end else if (start_edge) begin
    img_row <= 0; //Indirectly startup output
    img_col <= 0;
  end else if (video_adv) begin
    if (img_col == (SCREEN_W-1)) begin
      img_row <= (img_row + 13'd1);
      img_col <= 13'd0;
    end else begin
      img_col <= (img_col + 13'd1);
    end
  end
end


// Advance Image Index through Active Range (and Repeat-to-Scale)
reg  [12:0] img_scol;
reg  [15:0] img_pxl, sub_pxl;
reg  [ 2:0] sub_row, sub_col;

always @(posedge clock) begin
  if (start_edge) begin //Don't burden reset net & keep R&S available
    {img_pxl, sub_pxl} <= 0;
    img_scol <= SUB_SWIDTH;
    {sub_row, sub_col} <= {SUB_SCALE, SUB_SCALE};
  end else if (video_adv && pxl_active) begin //Advance within image area
    if (sub_col != 0) begin
      sub_col     <= (sub_col - 1);
    end else begin
      sub_col     <= SUB_SCALE;
      if (img_scol != 0) begin
        img_pxl   <= (img_pxl + 16'd1);
        img_scol  <= (img_scol - 1);
      end else begin
        img_scol  <= SUB_SWIDTH;
        if (sub_row != 0) begin
          img_pxl <= sub_pxl;
          sub_row <= (sub_row - 1);
        end else begin
          sub_row <= SUB_SCALE;
          img_pxl <= (img_pxl + 16'd1);
          sub_pxl <= (img_pxl + 16'd1);
        end
      end
    end
  end
end


// MUX in Continuous Data Fetch/Feed Over Background
wire [ 7:0] pixel_data;

//TODO: Just have simple, clean RUNNING flip-flop indicator
assign video_valid = (img_row < SCREEN_H);
assign video_gray  = pxl_active ? pixel_data : 8'd2;
assign video_rgb   = {3{video_gray}};

IMG_MEM img_mem(
  .clka(clock),
  .addra(img_pxl),
  .douta(pixel_data));

endmodule
