/*           PIX-MHz | hSTRT    hTOT  |vSTRT    vTOT |   hFP hBP |   vFP vBP |   hSP |   vSP
  640x480@60: 25.175 |H          800  |V         525 |H   16  48 |V   11  31 |H   96 |V    2
  640x480@72: 31.500 |H               |V             |H   24 128 |V    9  28 |H   40 |V    3
  640x480@75: 31.500 |H               |V             |H   16  48 |V   11  32 |H   96 |V    2
  640x480@85: 36.000 |H               |V             |H   32 112 |V    1  25 |H   48 |V    3
             PIX-MHz | hSTRT    hTOT  |vSTRT    vTOT |   hFP hBP |   vFP vBP |   hSP |   vSP
  800x600@56: 38.100 |H               |V             |H   32 128 |V    1  14 |H  128 |V    4
  800x600@60: 40.000 |H  128    1056  |V  24     628 |H   40  88 |V    1  23 |H  128 |V    4
  800x600@72: 50.000 |H               |V             |H   56  64 |V   37  23 |H  120 |V    6
  800x600@75: 49.500 |H               |V             |H   16 160 |V    1  21 |H   80 |V    2
  800x600@85: 56.250 |H               |V             |H   32 152 |V    1  27 |H   64 |V    3
             PIX-MHz | hSTRT    hTOT  |vSTRT    vTOT |   hFP hBP |   vFP vBP |   hSP |   vSP
 1024x768@60: 65.000 |H         1344  |V         806 |H   24 160 |V    3  29 |H  136 |V    6
 1024x768@70: 75.000 |H         1328  |V         806 |H   24 144 |V    3  29 |H  136 |V    6
 1024x768@75: 78.750 |H               |V             |H   16 176 |V    1  28 |H   96 |V    3
 1024x768@85: 94.500 |H               |V             |H   48 208 |V    1  36 |H   96 |V    3
             PIX-MHz | hSTRT    hTOT  |vSTRT    vTOT |   hFP hBP |   vFP vBP |   hSP |   vSP
1920x1200@60: 193.16 |H         2592  |V        1242 |H  128 336 |V    1  38 |H  208 |V    3

* 640x480@60: 25.175 |H          800  |V         525 |H   16  48 |V  -10  33 |H   96 |V    2*
* 800x600@60: 40.000 |H  122    1056  |V  24     628 |H   37  85 |V   -1  21 |H  128 |V    4*
*/

//NOTE: AD9980 pixel delay of 6 + HSOUT width of 32 + module conversion delay of 3 or 4

module VGA #(
  parameter [11:0] WIDTH   = 800, HEIGHT  = 600,
                   BACK_H  = 160, OFFS_H  =  28,
                   BACK_V  =  21, OFFS_V  =   4)
(
  input         reset,
  output        clock,

  input         start,
  output reg    start_ack,
  output reg    done,
  input         done_ack,

  input         video_ready,
  output        video_valid,
  output [ 7:0] video_gray,
  output [23:0] video_rgb,

  //  AD9980 Interface
  input         vga_data_clk,
  input  [ 7:0] vga_red, vga_green, vga_blue,
  input         vga_hsout,
  input         vga_vsout);

  // Buffer input pixel clock
  BUFG bufg_clock_vga( .I(vga_data_clk), .O(clock) );

  //Little 4-stage pipeline (capture, rgb-sum, rgb-div, rgb-avg)
  reg  [ 7:0] red_1, green_1, blue_1;
  reg  [23:0] rgb_2, rgb_3, rgb_4;
  reg  [ 9:0] sum_2;
  reg  [13:0] div_3;
  reg  [ 7:0] avg_4;

  wire [ 9:0] sum_expr;
  wire [13:0] div_expr;
  wire [ 7:0] avg_expr;

  // Approximate (r+b+g)/3 as (r+b+g)*(16 + 4 + 1)/64
  // Also clip to minimum of 4 to allow for colorspace mapping
  assign sum_expr = (red_1 + green_1 + blue_1),
          div_expr = (sum_2 << 4) + (sum_2 << 2) + sum_2,
          avg_expr = (|div_3[13:8]) ? div_3[13:6] : 8'd4; //if n>=4, n else 4

  always @(posedge clock) begin
    {red_1, green_1, blue_1} <= {vga_red, vga_green, vga_blue};
    {sum_2, rgb_2} <= {sum_expr, red_1,green_1,blue_1};
    {div_3, rgb_3} <= {div_expr, rgb_2};
    {avg_4, rgb_4} <= {avg_expr, rgb_3};
  end
  assign video_gray = avg_4,
          video_rgb = rgb_4;

  localparam [11:0] H_MAX = BACK_H + OFFS_H + WIDTH,
                    V_MAX = BACK_V + OFFS_V + HEIGHT;

  reg  [11:0] h_count,  v_count;
  wire        h_active, v_active;

  assign h_active = (h_count >= (BACK_H + OFFS_H)) &&
                    (h_count <  (BACK_H + OFFS_H + WIDTH));
  assign v_active = (v_count >= (BACK_V + OFFS_V)) &&
                    (v_count <  (BACK_V + OFFS_V + HEIGHT));
  assign video_valid = h_active && v_active;

  always @(posedge clock) begin
    if (reset) begin
      start_ack <= 1'b0;
      done <= 1'b0;

      h_count <= H_MAX;
      v_count <= V_MAX;
    end else begin
      if((v_count == V_MAX) && start && vga_vsout)
        v_count <= 12'd0;
      else if ((v_count < V_MAX) && (h_count == (H_MAX-1)))
        v_count <= v_count + 12'd1;

      if((v_count == V_MAX) && start && vga_vsout)
        start_ack <= 1'b1;
      else if (start_ack && ~start)
        start_ack <= 1'b0;

      if ((h_count == (H_MAX-1)) && (v_count == (V_MAX-1)))
        done <= 1'b1;
      else if (done && done_ack)
        done <= 1'b0;

      if(vga_hsout)
        h_count <= 12'd0;
      else if (h_count < H_MAX)
        h_count <= h_count + 12'd1;
    end
  end

endmodule
