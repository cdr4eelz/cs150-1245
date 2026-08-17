`timescale 1ns/1ps

`include "../cpuglobal.vh"
`include "../tuntap.vh"

/*
    UARTRVA patches a pair of RVA SHAKE busses through UART() for io serial lines
*/
module UARTRVA #(
    parameter ClockFreq=50_000_000, BaudRate=115_200
)(
    input   Clock, Reset,
    input   SIn,
    inout   `BUS_RVA_type(8) UARX,
    output  IRQ_RX, IRQ_TX,
    inout   `BUS_RVA_type(8) UATX,
    output  SOut
);
    //Individual RVA lines related to each serial line
    wire Rx_Ready, Rx_Valid, Tx_Valid, Tx_Ready;
    wire [7:0] Rx_Data, Tx_Data;

    // Prior clock state for "edge" -> "pulse" conversion
    reg WAS_Rx_Valid, WAS_Tx_Ready;
    always @(posedge Clock) begin:_REG_WAS_
        //NOTE:Avoid unnecessary resets --if (Reset) {WAS_Rx_Valid,WAS_Tx_Ready} <= 0; else
        {WAS_Rx_Valid,WAS_Tx_Ready} <= {Rx_Valid,Tx_Ready};
    end
    assign IRQ_RX = (Rx_Valid && !WAS_Rx_Valid);
    assign IRQ_TX = (Tx_Ready && !WAS_Tx_Ready);

    //UART & submodules do the work
    UART #(
        .ClockFreq(ClockFreq),
        .BaudRate(BaudRate)
    ) uartrva (
        .Clock(Clock),
        .Reset(Reset),

        // Receiver     (handshakes go both in/out)
        .SIn(SIn),
        .DataOut(Rx_Data), //out
        .DataOutValid(Rx_Valid), //out
        .DataOutReady(Rx_Ready), //in

        // Transmitter  (handshakes go both in/out)
        .SOut(SOut),
        .DataIn(Tx_Data), //in
        .DataInValid(Tx_Valid), //in
        .DataInReady(Tx_Ready) //out
    );

    //Tunnel individual signals => incoming RVA receiver SHAKE bus
    BUS_RVA_tun #(.InWidth(8)) TUN_RVA_Rx
    ( ._BUS_(UARX),
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );

    //Tap outgoing RVA transmitter SHAKE bus => individual signals
    BUS_RVA_tap #(.InWidth(8)) TAP_RVA_Tx
    ( ._BUS_(UATX),
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );

endmodule
