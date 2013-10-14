`include "CPUBusses.vh"
//TODO: Handle stall outside of here (implicit in masks

module MEMIOPlex //TODO: Set address with parameters (or even config register with param defaults)!
(
    inout `BUS_CPUGlobal_type   CPUGlobal,
    inout `BUS_MEMIO_type       IOMAP,

    input   SERIAL_RX,
    output  SERIAL_TX
);

wire  clk, rst, stl;
BUS_CPUGlobal_tap BUS_CPUGlobal
( ._BUS_(CPUGlobal),
    .CLK(clk), .RST(rst), .STL(stl)
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
wire         Tx_Ready;
reg  [ 7: 0] Tx_Data;
reg          Tx_Valid;

// TODO: Buffer 1 byte, since the "prep" approach probably imposes unnecessary (or impossible) timing constraints between the two clock realms because we make UART hold the byte until the instant that software is reading a value!
assign Rx_Ready = ((addr==12'h003) && rmask[0] && !stl);    // Is software now "in the act" of reading the uart data

always@(posedge clk) begin
    rdata = 32'bz;
    if (rst) begin
        Tx_Valid = 0;       Tx_Data = 7'bz; //TODO: Only use z for simulation
    end else begin
        if (Tx_Valid && Tx_Ready) begin
            $display("MEMIO: Shake");
            Tx_Valid = 0;   Tx_Data = 7'bz;
        end
        
        case (addr) 
            12'h002: if (wmask[0]) begin   // Avoid accidental zero writes if doing sb or sh near but not on low byte
                $display("MEMIO: Write");
                Tx_Valid = 1;   Tx_Data = wdata[7:0];   // Let software stomp on prior value
            end
        endcase
        
        case (addr)     // The rmask check is just to avoid currently non-existent side effects of read
            12'h000: if (rmask[0]) rdata = {31'b0, Tx_Ready};
            12'h001: if (rmask[0]) rdata = {31'b0, Rx_Valid};
            12'h002: if (rmask[0]) rdata = {24'b0, Tx_Data};    // Read back last written value, just for fun
            12'h003: if (rmask[0]) rdata = {24'b0, Rx_Data};    // Could be bogus if Rx_Valid was floppy or UART's setup time on Rx_Ready was violated
        endcase
        
        //if (rmask[0]) $display("MEMIO: A=%h, W=%h/%b, R=%h/%b", addr, wdata, wmask, rdata, rmask);
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
