module UATransmit(
  input   Clock,
  input   Reset,

  input   [7:0] DataIn,
  input         DataInValid,
  output        DataInReady,

  output        reg SOut
);
  // for log2 function
  `include "util.vh"

  //--|Parameters|--------------------------------------------------------------

  parameter   ClockFreq         =   100_000_000;
  parameter   BaudRate          =   115_200;

  // See diagram in the lab guide
  localparam  SymbolEdgeTime    =   ClockFreq / BaudRate;
  localparam  ClockCounterWidth =   log2(SymbolEdgeTime);

  //--|Solution|----------------------------------------------------------------

  reg [3:0] BitCount;
  reg [ClockCounterWidth-1:0] ClockCounter;
  reg [7:0] Data;

  wire Idle, SymbolEdge;

  assign DataInReady = (BitCount<=1); // Use "<= 1" if allowing stop-bit overlap

  assign SymbolEdge = (ClockCounter == SymbolEdgeTime-1);
  assign Idle = (BitCount == 0);

  always@(posedge Clock) begin // Manage ClockCounter
    ClockCounter <= (Reset || SymbolEdge || Idle) ? 0 : ClockCounter + 1;
  end

  always@(posedge Clock) begin // Advance bit counter
    if (Reset) BitCount <= 0;
    else if (SymbolEdge) BitCount <= BitCount - 1;
  end

  always@(posedge Clock) begin // Grab input data (synchronous)
    if (Reset) Data <= 0;
    else if (DataInReady && DataInValid) Data <= DataIn;
  end

  always@(BitCount, Data) begin // Drive SOut (in MUX style based on our state)
    SOut <= 1'b1; // Presume IDLE
    case (BitCount)
      10: SOut <= 1'b0;
      11,1,0: SOut <= 1'b1;
      9,8,7,6,5,4,3,2: SOut <= Data[9-BitCount];
    endcase
  end


endmodule
