`ifndef MACROSAFE
`define MACROSAFE
`endif // required to get this to compile...
`include "../base_util/const.vh"

module UAReceive(
  input   Clock,
  input   Reset,

  output  [7:0] DataOut,
  output        DataOutValid,
  input         DataOutReady,

  input         SIn
);
//// for log2 function
//`include "../base_util/util.vh"

  //--|Parameters|--------------------------------------------------------------

  parameter   CLOCK_FREQ        =   100_000_000;
  parameter   BAUD_RATE         =       115_200;

  // See diagram in the lab guide
  localparam  SymbolEdgeTime    =   CLOCK_FREQ / BAUD_RATE;
  localparam  SampleTime        =   SymbolEdgeTime / 2;
  localparam  ClockCounterWidth =   `log2(SymbolEdgeTime);

  //--|Declarations|------------------------------------------------------------

  wire                            SymbolEdge;
  wire                            Sample;
  wire                            Start;
  wire                            RXRunning;

  reg     [9:0]                   RXShift = 10'b00_0000_0000;;
  reg     [3:0]                   BitCounter = 4'd0;
  reg     [ClockCounterWidth-1:0] ClockCounter = 0;
  reg                             HasByte = 1'b0;

  //--|Signal Assignments|------------------------------------------------------

  // Goes high at every symbol edge
  assign  SymbolEdge   = (ClockCounter == SymbolEdgeTime - 1);

  // Goes high halfway through each symbol
  assign  Sample        = ClockCounter == SampleTime;

  // Goes high when it is time to start receiving a new character
  assign  Start         = !SIn && !RXRunning;

  // Currently receiving a character
  assign  RXRunning     = BitCounter != 4'd0;

  // Outputs
  assign  DataOut = RXShift[8:1];
  assign  DataOutValid = HasByte && !RXRunning;

  //--|Counters|----------------------------------------------------------------

  // Counts cycles until a single symbol is done
  always @ (posedge Clock) begin
    ClockCounter <= (Start || Reset || SymbolEdge) ? 0 : ClockCounter + 1;
  end

  // Counts down from 10 bits for every character
  always @ (posedge Clock) begin
    if (Reset) begin
      BitCounter <= 0;
    end else if (Start) begin
      BitCounter <= 10;
    end else if (SymbolEdge && RXRunning) begin
      BitCounter <= BitCounter - 1;
    end
  end

  //--|Shift Register|----------------------------------------------------------
  always @(posedge Clock) begin
    if (Reset) begin
      RXShift <= 10'b00_0000_0000;
    end else if (Sample && RXRunning) begin
      RXShift <= {SIn, RXShift[9:1]};
    end
  end

  
  //--|Extra State For Ready/Valid|---------------------------------------------
  always @ (posedge Clock) begin
    if (Reset) HasByte <= 1'b0;
    else if (BitCounter == 1 && SymbolEdge) HasByte <= 1'b1;
    else if (DataOutReady) HasByte <= 1'b0;
  end

endmodule
