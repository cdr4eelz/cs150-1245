module CPUDumpUART #(
    parameter CPU_FREQ  = 50_000_000,
    parameter BAUD_RATE =    115_200,
    parameter DATALEN   = 256
)(
    input clk, rst, stall,

    // Serial
    input  SerialRX,
    output SerialTX
);

    wire [7:0] DataInTX, DataOutRX, TX_Data;
    wire DataInReadyTX, DataInValidTX;
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

    reg  [13: 0]    ADDR;
    wire [11: 0]    ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W;

    // This is the very simple "dump", TX for each RX
    assign DataOutReadyRX = rst ? 1'b0 : !PendingTX;
    assign DataInTX = rst ? 8'd0 : DataOut_r;
    assign DataInValidTX = rst ? 1'b0 : PendingTX;
    always @(posedge clk) begin
        if (rst) begin
            DataOut_r <= 0;
            PendingTX <= 1'b0;
            ADDR <= 14'd0;
        end else if (!stall) begin
            if (DataOutValidRX && DataOutReadyRX) begin
                //DataOut_r <= DataOutRX;
                DataOut_r <= TX_Data;  // DataOutRX;
                PendingTX <= 1'b1;
                ADDR <= ADDR;
            end else if (DataInValidTX && DataInReadyTX) begin
                DataOut_r = 8'd38;
                PendingTX <= 1'b0;
                ADDR <= (ADDR >= DATALEN) ? 0 : (ADDR + 1);
            end
        end
    end
/*
    bios_mem bram_bios (  //IP BRAM works, whereas inferred BRAM seems flawed
        .clka(clk),     // input wire clka
        .ena(!stall),   // input wire ena
        .addra(ADDR_W), // input wire [11 : 0] addra
        .douta(DATA_W), // output wire [31 : 0] douta
        .clkb(clk),     // input wire clkb
        .enb(1'b0),     // input wire enb
        .addrb(12'd0),  // input wire [11 : 0] addrb
        .doutb()        // output wire [31 : 0] doutb
    );
*/
    bios_mem_24 bram_bios
    (   .clk(clk),  .ena(!stall),
        .addra(ADDR_W), .douta(DATA_W),//OUT-32
        .enb(1'b0), .addrb(12'd0), .doutb()
    );

    assign ADDR_W   = ADDR[13: 2];
    assign ADDR_N   = ADDR[ 1: 0];
    assign TX_Data  = (ADDR_N[1]) ? ( (ADDR_N[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                                  : ( (ADDR_N[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);

endmodule
