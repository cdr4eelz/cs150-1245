`include "CPUBusses.vh"

module MEMIOPlex#(
    parameter BUFSIZE=0
)( //TODO: Set address with parameters (or even config register with param defaults)!
    input   clk, rst, stall,
    inout   `BUS_MMAP_type      IOMAP,
    inout   `BUS_SHAKE_type(8)  RVA_RX, RVA_TX
);

    localparam _MAGIC_SANE_ = 15'h7DE3;
    reg [14:0] MAGIC_SANE_;
    always@(posedge clk) if (rst) MAGIC_SANE_ <= _MAGIC_SANE_;
    wire _SANE_ = (MAGIC_SANE_ == _MAGIC_SANE_);

    // Minimal statistics
    reg  [15: 0]    CNT_Rx, CNT_Tx;

    // Translate from Memory Mapped read/write actions into Ready/Valid interactions:
    wire [11: 0]    addr;
    wire [ 3: 0]    rmask, wmask;
    wire [31: 0]    wdata;
    reg  [31: 0]    rdata; // REGISTER to mimic synchronous memory access

    // Forward patchwork (to UART ready/valid interfaces below):
    wire            Rx_Ready;   // OUT: We offer to take a byte
    wire            Rx_Valid;   // IN : UART announcing a byte
    wire [ 7: 0]    Rx_Data;    // IN : Data from UART
    wire [ 7: 0]    Tx_Data;    // OUT: Data to UART
    wire            Tx_Valid;   // OUT: We announce a byte
    wire            Tx_Ready;   // IN : UART can take a byte from us

    wire ena = |(rmask | wmask);

generate if (BUFSIZE==0) begin:NOBUFF   // Direct Software-to-UART approach:

    // Set these up before the clock (continuous drive) so UART sees them within setup/detect time
    assign Tx_Data  = (Tx_Valid) ? wdata[7:0] : 8'h33;
    assign Tx_Valid = ena && wmask[0] && (addr==12'h002);
    assign Rx_Ready = ena && rmask[0] && (addr==12'h003);

    always@(posedge clk) begin
        if (rst) begin
            CNT_Tx <= 0;
            CNT_Rx <= 0;
            rdata <= 32'hFEEBDAED;
        end else if (ena) begin // Can check rmask bits to avoid sb or sh nearby
            rdata <= 32'hFFFF_FFFF;
            case (addr)
                12'h000: if (rmask[0]) begin    
                    if (Tx_Ready) $display("MEMIO: Poll Tx (%b)", Tx_Ready);
                    rdata  <= {31'b0, Tx_Ready};
                end
                12'h001: if (rmask[0]) begin  
                    if (Rx_Valid) $display("MEMIO: Poll Rx (%b)", Rx_Valid);
                    rdata  <= {31'b0, Rx_Valid};
                end
                12'h002: if (wmask[0]) begin  
                    $display("MEMIO: Tx Shake (%h, %d) CNT: %d", Tx_Data, Tx_Data, CNT_Tx+1);
                    CNT_Tx <= CNT_Tx + 1;
                end
                12'h003: if (rmask[0]) begin  
                    $display("MEMIO: Rx Shake (%h, %d) CNT: %d", Rx_Data, Rx_Data, CNT_Rx+1);
                    CNT_Rx <= CNT_Rx + 1;
                    rdata <= {24'b0, Rx_Data};
                end
            endcase
        end
    end

end else begin:BUFFY  // Mini-buffers approach:

    reg  [ 7: 0]    BUF_TxData, BUF_RxData; // Tiny buffers to ease the xfer
    reg             BUF_TxFull, BUF_RxFull; // Is buffer ocupied?

    // Set these up before the clock (continuous drive)
    assign Rx_Ready = !BUF_RxFull;
    assign Tx_Data  = BUF_TxData;
    assign Tx_Valid = BUF_TxFull;

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

            if (ena && rmask[0]) case (addr)   // Could be (|rmask) but we only care about low byte
                12'h000: rdata <= {31'b0, !BUF_TxFull && Tx_Ready}; // Checking both maybe excessive?
                12'h001: rdata <= {31'b0, BUF_RxFull};  // TODO: Could we safely OR with real UART rx?
    //          12'h002: rdata <= {24'b0, BUF_TxData};  // Read back last written but unsent value, just for fun
                12'h003: begin  // Read from our mini-buffer (and indicate that there is room)
                    rdata       <= {24'b0, BUF_RxData};
                    BUF_RxFull  <= 0;
                end
            endcase
            
            if (ena && wmask[0]) case (addr)   // Avoid zero writes if doing sb or sh near but not ON low byte
                12'h002: begin
                    $display("MEMIO: Write queued (%h)", wdata);
                    BUF_TxData  <= wdata[7:0];
                    BUF_TxFull  <= 1;   // Don't check if already full, just overwrite with new value
                end
            endcase
        end
    end

end endgenerate


    // Patch local wires into outer world:

    BUS_MMAP_tap TAP_MMAP_IOMAP
    ( ._BUS_(IOMAP), ._STALL_(stall), //TUN side might also apply stall
        .Addr(addr),
        .RMask(rmask), .RData(rdata),
        .WMask(wmask), .WData(wdata)
    );

    BUS_SHAKE_tap #(.InWidth(8)) TAP_SHAKE_Rx
    ( ._BUS_(RVA_RX),
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );

    BUS_SHAKE_tun #(.InWidth(8)) TUN_SHAKE_Tx
    ( ._BUS_(RVA_TX),
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );

endmodule
