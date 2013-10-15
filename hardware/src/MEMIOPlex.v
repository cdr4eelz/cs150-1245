`include "CPUBusses.vh"
//TODO: Handle stall outside of here (implicit in masks
//TODO: Only use z for simulation

module MEMIOPlex //TODO: Set address with parameters (or even config register with param defaults)!
(
    inout `BUS_CPUGlobal_type   CPUGlobal,
    inout `BUS_MEMIO_type       IOMAP,

    input   SERIAL_RX,
    output  SERIAL_TX
);

wire  clk, rst, stall;
BUS_CPUGlobal_tap BUS_CPUGlobal
( ._BUS_(CPUGlobal),
    .CLK(clk), .RST(rst), .STL(stall)
);

// Translate Memory Mapped read/write actions FROM these MEMIO-style...
wire [11: 0] addr;
wire [ 3: 0] rmask, wmask;
wire [31: 0] wdata;
reg  [31: 0] rdata; // Register Mimic synchronous memory behavior
// ...INTO appropriate handshakes, clock border management and graceful
//    stall handling with these Tx/Rx UART lines/registers:
wire         Rx_Valid;
wire [ 7: 0] Rx_Data;
wire         Rx_Ready;
wire         Tx_Ready;  // UART is ready for a byte on the upcoming clock
reg  [ 7: 0] Tx_Data;   // Both sides consider data xfered only if Ready&&Valid @posedge-clk
reg          Tx_Valid;  // We are holding valid data for UART to grab

// TODO: Buffer 1 byte, since the "prep" approach probably imposes unnecessary (or impossible) timing constraints between the two clock realms because we make UART hold the byte until the instant that software is reading a value!

reg inStall; // Distinguish active stall from pending stall
always@(posedge clk) inStall <= stall && ~rst;

// Is software now "in the act" of reading the uart data
assign Rx_Ready = (~inStall && (addr==12'h003) && rmask[0]);

always@(posedge clk) begin
    rdata <= 32'bz;
    if (rst) begin
        Tx_Valid <= 0;
        Tx_Data  <= 7'bz;
    end else begin
        if (Tx_Valid && Tx_Ready) begin
            $display("MEMIO: Tx Shake");
            Tx_Valid <= 0;
            Tx_Data <= 7'bz;
        end
        if (~inStall) begin
            case (addr) 
                12'h002: if (wmask[0]) begin   // Avoid accidental zero writes if doing sb or sh near but not on low byte
                    $display("MEMIO: Write pending");
                    Tx_Valid <= 1;
                    Tx_Data  <= wdata[7:0];   // Let software stomp on prior value
                end
            endcase
            
            case (addr)     // The rmask check is just to avoid currently non-existent side effects of read
                12'h000: if (rmask[0]) rdata <= {31'b0, Tx_Ready};
                12'h001: if (rmask[0]) rdata <= {31'b0, Rx_Valid};
                12'h002: if (rmask[0]) rdata <= {24'b0, Tx_Data};    // Read back last written value, just for fun
                12'h003: if (rmask[0]) rdata <= {24'b0, Rx_Data};    // Could be bogus if Rx_Valid was floppy or UART's setup time on Rx_Ready was violated
            endcase
            
            //if (rmask[0]) $display("MEMIO: A=%h, W=%h/%b, R=%h/%b", addr, wdata, wmask, rdata, rmask);
        end
    end
end


BUS_MEMIO_tap BUS_MEMIO_IOMAP
( ._BUS_(IOMAP),
    .Addr(addr),
    .RMask(rmask),          .RData(rdata),
    .WMask(wmask),          .WData(wdata)
);

UART uart
(   .Clock(clk), .Reset(rst), // Shield UART from direct stalling knowledge
    //   RECEIVER               //   TRANSMITTER
    .DataOutReady(Rx_Ready),    .DataInReady(Tx_Ready),
    .DataOutValid(Rx_Valid),    .DataInValid(Tx_Valid),
    .DataOut     (Rx_Data),     .DataIn     (Tx_Data),
    
    .SIn         (SERIAL_RX),   .SOut       (SERIAL_TX)
);

endmodule
