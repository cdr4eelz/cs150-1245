module PatternGenerator #(
  parameter CLOCK_HZ = 40_000_000,
  parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600,
  parameter SCENES_PER_SEC = 1)
(
  // Controller interface
  input  wire     clock,
  input  wire     reset,

  // DVI Interface
  output wire[23:0] video,
  output wire       video_valid,
  input  wire       video_ready
);

//Compute ideal sceen duration as # of rows (might not fall on frame boundary)
localparam SCENE_TICKS = CLOCK_HZ / SCENES_PER_SEC;

reg  [63:0] bigCLOCK;
reg  [31:0] curCOL, curROW, curFRAME;
reg         curSCENE, nextSCENE;
reg  [23:0] curRGB, nextRGB;
reg         validRGB;

//Could use fast-counter/pixelrange util instead of our own
wire rollCOL = (curCOL >= SCREEN_WIDTH-1);
wire rollROW = (curROW >= SCREEN_HEIGHT-1);
wire [ 2:0] scale = curFRAME[6:4];
//wire [ 2:0] idx   = {curSCENE, curROW[scale], curCOL[scale+1]}; //Scene in MSB
wire [ 2:0] idx   = {curSCENE, 1'b0, curCOL[scale+1]}; //Scene in MSB
wire advanceRVA  = video_valid && video_ready; //reset will trump this

assign video       = curRGB;
assign video_valid = validRGB;

always @(posedge clock) begin
  if (reset) begin
    bigCLOCK <= 64'd0;
    {curSCENE, nextSCENE} <= {1'b0, 1'b0};
    {curCOL, curROW, curFRAME} <= {32'd0, 32'd0, 32'd0};
    {validRGB, curRGB} <= {1'b0, 24'h000000};
    //First RVA offer is cycle AFTER noticing deasserted reset!
  end else begin
    if (advanceRVA) begin //They got a pixel, move on!
      curRGB <= nextRGB; //Offer pending pixel from combinational-logic below
      case ({rollROW, rollCOL}) //Manage our col/row/frame/scene business
        (2'b11): begin
          curFRAME <= (curSCENE == nextSCENE) ? (curFRAME+1) : 32'd0;
          curSCENE <= nextSCENE;
          {curCOL,curROW} <= {32'd0, 32'd0};
        end
        (2'b01): begin
          {curCOL,curROW} <= {32'd0, curROW+1};
        end
        //2'b10 just means we're ON last row but not yet at end
        default: begin
          curCOL <= curCOL+1;
        end
      endcase
    end

    if (bigCLOCK == (SCENE_TICKS-1)) begin
      nextSCENE <= !nextSCENE;
      bigCLOCK <= 64'd0;
      $strobe("* %t C:%h R:%h F:%h S:%h  nS:%b  idx:%b (%h)", $time,
                curCOL, curROW, curFRAME, curSCENE, nextSCENE, idx, nextRGB);
    end else bigCLOCK <= bigCLOCK+1;

    validRGB <= 1'b1; //Ensure it's set (but not during synchronous reset)
  end
end

always @(*) begin
  nextRGB = 24'hFFFFFF; //{curCOL, curROW, curSCENE}; //(curRGB + curFRAME + 1);
  case (idx) //Could be table lookup
    3'b000: nextRGB = 24'hFF0000;
    3'b001: nextRGB = 24'h0F880F;
    3'b010: nextRGB = 24'h00FF00;
    3'b011: nextRGB = 24'h1F2030;
    3'b100: nextRGB = 24'h0F880F;
    3'b101: nextRGB = 24'h88FF88;
    3'b110: nextRGB = 24'h880088;
    3'b111: nextRGB = 24'hFF0000;
  endcase
end

endmodule
