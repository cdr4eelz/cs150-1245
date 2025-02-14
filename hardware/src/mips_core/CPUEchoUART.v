module CPUEcho #(
    parameter CPU_FREQ = 50_000_000,
    parameter BaudRate = 115_200
)(
    input clk, rst, stall,

    // Serial
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

    wire [7:0] DataIn;
    wire DataInReady, DataInValid;
    wire [7:0] DataOut;
    reg [7:0] DataOut_r;
    wire DataOutReady, DataOutValid;
    reg PendingTX;

    UART #(  // Note this module ties RX & TX lines to IO registers
        .ClockFreq(CPU_FREQ),
        .BaudRate(BaudRate)
    ) uart ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .DataOut(DataOut),
        .DataOutValid(DataOutValid), .DataOutReady(DataOutReady),
        .SOut(FPGA_SERIAL_TX), .DataIn(DataIn),
        .DataInValid(DataInValid), .DataInReady(DataInReady)
    );

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
