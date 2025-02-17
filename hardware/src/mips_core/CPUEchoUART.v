module CPUEchoUART #(
    parameter CPU_FREQ  = 50_000_000,
    parameter BAUD_RATE =    115_200
)(
    input clk, rst, stall,

    // Serial
    input  SerialRX,
    output SerialTX
);

    wire [7:0] DataInTX;
    wire DataInReadyTX, DataInValidTX;
    wire [7:0] DataOutRX;
    reg [7:0] DataOut_r = 8'd35;
    wire DataOutReadyRX, DataOutValidRX;
    reg PendingTX = 1'b0;

//  This "UART" module avoids redundant top-level IOB registers...
//      ...BUT has one register set between IOB's and TX/RX logic.
    UART #(
        .CLOCK_FREQ(CPU_FREQ),  .BAUD_RATE(BAUD_RATE)
    ) uartModule( .Clock(clk),  .Reset(rst),
        .DataInTX(DataInTX),  .DataInValidTX(DataInValidTX),
        .DataInReadyTX(DataInReadyTX),  .SOutTX(SerialTX),
        .DataOutRX(DataOutRX),  .DataOutValidRX(DataOutValidRX),
        .DataOutReadyRX(DataOutReadyRX),  .SInRX(SerialRX)
    );

    // This is the very simple "echo", TX for each RX
    assign DataOutReadyRX = !rst;
    assign DataInTX = rst ? 8'd0 : DataOut_r;
    assign DataInValidTX = rst ? 1'b0 : PendingTX;
    always @(posedge clk) begin
        if (rst) begin
            DataOut_r <= 0;
            PendingTX <= 1'b0;
        end else if (!stall) begin
            if (DataOutValidRX && DataOutReadyRX) begin
                DataOut_r <= DataOutRX;
                PendingTX <= 1'b1;
            end else if (DataInValidTX && DataInReadyTX) begin
                PendingTX <= 1'b0;
            end
        end
    end

endmodule
