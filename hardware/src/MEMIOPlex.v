`include "CPUBusses.vh"

module MEMIOPlex
(   input clk, rst,
    
    inout `BUS_MEMIO_type   IOMAP,

    input   SERIAL_RX,
    output  SERIAL_TX
);

// Translate Memory Mapped read or write accesses from:
wire [11: 0] addr;
wire [ 3: 0] rmask, wmask;
wire [31: 0] rdata, wdata;
// ...to appropriate handshakes with these Tx/Rx UART lines/registers:
wire         Tx_Ready,   Rx_Valid;
reg  [ 7: 0] Tx_Data,    Rx_Data;
reg          Tx_Valid,   Rx_Ready;

always@(posedge clk) begin
    if (rst) begin
        Tx_Data = 0;    Rx_Data = 0;
        Tx_Valid = 0;   Rx_Ready = 0;
    end else begin
    end
end


BUS_MEMIO_tap BUS_MEMIO_IOMAP
( ._BUS_(IOMAP),
    .Addr(addr),
    .RMask(rmask),          .RData(rdata),
    .WMask(wmask),          .WData(wdata)
);

UART uart
(   .clk(clk), .reset(rst),
    //   RECEIVER               //   TRANSMITTER
    .DataOutReady(Rx_Ready),    .DataInReady(Tx_Ready),
    .DataOutValid(Rx_Valid),    .DataInValid(Tx_Valid),
    .DataOut     (Rx_Data),     .DataIn     (Tx_Data),
    
    .SIn         (SERIAL_RX),   .SOut       (SERIAL_TX)
);

endmodule
