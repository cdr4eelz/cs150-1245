module CPUEchoUART #(
    parameter CPU_FREQ  = 50_000_000,
    parameter BAUD_RATE =    115_200
)(
    input clk, rst, stall,

    // Serial
    input  SerialRX,
    output SerialTX
);

    wire [7:0] DataIn;
    wire DataInReady, DataInValid;
    wire [7:0] DataOut;
    reg [7:0] DataOut_r;
    wire DataOutReady, DataOutValid;
    reg PendingTX;

//  Bypass old "UART" module to avoid redundant IOB registers...
    UATransmit #(
        .CLOCK_FREQ(CPU_FREQ),  .BAUD_RATE(BAUD_RATE)
    ) uatransmit( .Clock(clk),  .Reset(rst),
        .DataIn(DataIn),  .DataInValid(DataInValid),
        .DataInReady(DataInReady),  .SOut(SerialTX)
    );
    UAReceive #(
        .CLOCK_FREQ(CPU_FREQ),  .BAUD_RATE(BAUD_RATE)
    ) uareceive( .Clock(clk),  .Reset(rst),
        .DataOut(DataOut),  .DataOutValid(DataOutValid),
        .DataOutReady(DataOutReady),  .SIn(SerialRX)
    );

    // This is the very simple "echo", TX for each RX
    assign DataOutReady = 1'b1;
    assign DataIn = DataOut_r, DataInValid = PendingTX;
    always @(posedge clk) begin
        if (rst) begin
            DataOut_r <= 0;
            PendingTX <= 1'b0;
        end else if (!stall) begin
            if (DataOutValid && DataOutReady) begin
                DataOut_r <= DataOut;
                PendingTX <= 1'b1;
            end else if (DataInValid && DataInReady) begin
                PendingTX <= 1'b0;
            end
        end
    end

endmodule
