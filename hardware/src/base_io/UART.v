module UART(
    input  wire         Clock,
    input  wire         Reset,

    input  wire[7:0]    DataInTX,
    input  wire         DataInValidTX,
    output wire         DataInReadyTX,

    output wire[7:0]    DataOutRX,
    output wire         DataOutValidRX,
    input  wire         DataOutReadyRX,

    output wire         SOutTX,
    input  wire         SInRX
);
    parameter   CLOCK_FREQ  =   50_000_000;
    parameter   BAUD_RATE   =      115_200;

    // UART for 2019 & 2024 adds these registers in addition to top-level IOBs
    reg serial_in_reg = 1'b1, serial_out_reg = 1'b1;
    wire serial_out_tx;
    assign SOutTX = serial_out_reg;
    always @ (posedge Clock) begin
        serial_out_reg  <= Reset ? 1'b1 : serial_out_tx;
        serial_in_reg   <= Reset ? 1'b1 : SInRX;
    end

    UATransmit #(
        .CLOCK_FREQ(    CLOCK_FREQ),
        .BAUD_RATE(     BAUD_RATE)
    ) uatransmit (
        .Clock(Clock),  .Reset(Reset),
        .DataIn(        DataInTX),
        .DataInValid(   DataInValidTX),
        .DataInReady(   DataInReadyTX),
        .SOut(          serial_out_tx)
    );

    UAReceive #(
        .CLOCK_FREQ(    CLOCK_FREQ),
        .BAUD_RATE(     BAUD_RATE)
    ) uareceive (
        .Clock(Clock),  .Reset(Reset),
        .DataOut(       DataOutRX),
        .DataOutValid(  DataOutValidRX),
        .DataOutReady(  DataOutReadyRX),
        .SIn(           serial_in_reg)
    );

endmodule
