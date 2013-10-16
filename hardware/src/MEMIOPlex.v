`include "CPUBusses.vh"

module MEMIOPlex //TODO: Set address with parameters (or even config register with param defaults)!
(
    input   clk, rst,   // NOTE: Stall handled externally (via MEMIO bus enable lines)
    inout   `BUS_MEMIO_type IOMAP,
    input   SERIAL_RX,
    output  SERIAL_TX
);

// Translate from Memory Mapped read/write actions into Ready/Valid interactions:
wire [11: 0] addr;
wire [ 3: 0] rmask, wmask;
wire [31: 0] wdata;
reg  [31: 0] rdata; // Register to mimic synchronous memory access

// Mini-buffers:
reg  [ 7: 0]    BUF_TxData, BUF_RxData; // Tiny buffers to ease the xfer
reg             BUF_TxFull, BUF_RxFull; // Is buffer ocupied?

// Forward patchwork (to UART ready/valid interfaces below):
wire            Rx_Ready    = !BUF_RxFull;  // Offer to take a byte from UART
wire            Rx_Valid;                   // UART announcing a byte for us
wire [ 7: 0]    Rx_Data;                    // Data from UART to us
wire [ 7: 0]    Tx_Data     = BUF_TxData;   // Data from us to UART
wire            Tx_Valid    = BUF_TxFull;   // Announce a byte for UART
wire            Tx_Ready;                   // UART can take a byte from us

always@(posedge clk) begin
    if (rst) begin
        BUF_RxFull  <= 0;
        BUF_TxFull  <= 0;
        BUF_RxData  <= 8'h97;   // Arbitrary flag to spot premature receive...
        BUF_TxData  <= 8'h98;   // ...or xmit
        rdata <= 32'hFEEBDAED;
    end else begin
        if (Rx_Ready && Rx_Valid) begin
            $display("MEMIO: Rx Shake (%h)", Rx_Data);
            BUF_RxData  <= Rx_Data;
            BUF_RxFull  <= 1;
        end

        if (Tx_Ready && Tx_Valid) begin
            $display("MEMIO: Tx Shake (%h)", Tx_Data);
            BUF_TxFull  <= 0;
            BUF_TxData  <= 8'h99;   // Arbitrary value to spot double xmit errors
        end

        if (rmask[0]) case (addr)   // Could be (|rmask) but we only care about low byte
            12'h000: rdata <= {31'b0, !BUF_TxFull && Tx_Ready}; // Checking both maybe excessive?
            12'h001: rdata <= {31'b0, BUF_RxFull};  // TODO: Could we safely OR with real UART rx?
//          12'h002: rdata <= {24'b0, BUF_TxData};  // Read back last written but unsent value, just for fun
            12'h003: begin  // Read from our mini-buffer (and indicate that there is room)
                rdata       <= {24'b0, BUF_RxData};
                BUF_RxFull  <= 0;
            end
        endcase
        
        if (wmask[0]) case (addr)   // Avoid zero writes if doing sb or sh near but not ON low byte
            12'h002: begin
                $display("MEMIO: Write queued (%h)", wdata);
                BUF_TxData  <= wdata[7:0];
                BUF_TxFull  <= 1;   // Don't check if already full, just overwrite with new value
            end
        endcase
        
        //if (rmask[0]) $display("MEMIO: A=%h, W=%h/%b, R=%h/%b", addr, wdata, wmask, rdata, rmask);
    end
end


// Patch local wires into outer world:

BUS_MEMIO_tap BUS_MEMIO_IOMAP
( ._BUS_(IOMAP),
    .Addr(addr),
    .RMask(rmask),          .RData(rdata),
    .WMask(wmask),          .WData(wdata)
);

UART uart
(   .Clock(clk), .Reset(rst),
    //   RECEIVER               //   TRANSMITTER
    .DataOutReady(Rx_Ready),    .DataInReady(Tx_Ready),
    .DataOutValid(Rx_Valid),    .DataInValid(Tx_Valid),
    .DataOut     (Rx_Data),     .DataIn     (Tx_Data),
    
    .SIn         (SERIAL_RX),   .SOut       (SERIAL_TX)
);

endmodule
