`timescale 1ns/1ps

`ifndef MACROSAFE
`define MACROSAFE
`endif // required to get this to compile...
`include "../base_util/Const.v"

module UATransmit(
    input   Clock, Reset,

    input   [7:0] DataIn,
    input         DataInValid,
    output        DataInReady,

    output        SOut
);
//  // for log2 function
//  `include "../base_util/util.vh"

    //--|Parameters|--------------------------------------------------------------

    parameter   ClockFreq         =   100_000_000;
    parameter   BaudRate          =   115_200;

    // See diagram in the lab guide
    localparam  SymbolEdgeTime    =   ClockFreq / BaudRate;
    localparam  ClockCounterWidth =   `log2(SymbolEdgeTime);

    //--|Solution|----------------------------------------------------------------

    reg [3:0] BitCount;
    reg [ClockCounterWidth-1:0] ClockCounter;
    reg [9:0] ShiftOut;

    wire TXRunning, SymbolEdge, StartTX;

    assign DataInReady = ((BitCount == 0) || ((BitCount == 1) && SymbolEdge));
    assign SOut = ShiftOut[0]; //(TXRunning) ? ShiftOut[0] : 1'b1;

    assign SymbolEdge = (ClockCounter == SymbolEdgeTime-1);
    assign TXRunning = (BitCount != 0);
    assign StartTX = (DataInReady && DataInValid);

    always@(posedge Clock) begin // Manage ClockCounter
        ClockCounter <= (Reset || SymbolEdge || !TXRunning) ? 0 : ClockCounter + 1;
    end

    always@(posedge Clock) begin // Manage BitCounter & shifting
        if (Reset) begin
            BitCount <= 0;
            ShiftOut <= 10'b1111_1111_11;
        end else if (StartTX) begin // Entering TXRunning "state"
            BitCount <= 4'd11; // NOTE: extra count to ensure stop bit fully sent
            ShiftOut <= {DataIn[7:0], 1'b0, 1'b1}; // LSB shifted out first!
        end else if (TXRunning && SymbolEdge) begin
            BitCount <= BitCount - 1;
            ShiftOut <= {1'b1, ShiftOut[9:1]};
        end
    end

endmodule
