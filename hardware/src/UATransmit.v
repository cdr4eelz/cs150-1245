module UATransmit(
  input   Clock,
  input   Reset,

  input   [7:0] DataIn,
  input         DataInValid,
  output        DataInReady,

  output        SOut
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
  reg [9:0] ShiftOut;

  wire TXRunning, SymbolEdge, StartTX;

  assign DataInReady = (BitCount == 0); // Use "<= 1" if allowing stop-bit overlap
  assign SOut = (TXRunning) ? ShiftOut[0] : 1'b1;

  assign SymbolEdge = (ClockCounter == SymbolEdgeTime-1);
  assign TXRunning = (BitCount != 0);
  assign StartTX = (!TXRunning && DataInValid);

  always@(posedge Clock) begin // Manage ClockCounter
    ClockCounter <= (Reset || SymbolEdge || !TXRunning) ? 0 : ClockCounter + 1;
  end

  always@(posedge Clock) begin // Manage BitCounter & shifting
    if (Reset) begin
      BitCount <= 0;
      //shiftout <= 8'b0;
    end else begin
      if (TXRunning) begin
        if (SymbolEdge) begin
          BitCount <= BitCount - 1;
          ShiftOut <= (ShiftOut >> 1); //{1'b0, ShiftOut[9:1]};
        end
      end else if (StartTX) begin // Entering TXRunning "state"
        BitCount <= 4'd10; // Implicitly de-assert StartTX
        ShiftOut <= {1'b1, DataIn, 1'b0}; // LSB shifted out first!
      end // else idling!
    end
  end

endmodule
