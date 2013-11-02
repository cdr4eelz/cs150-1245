`include "CPUBusses.vh"

module MEMIOPlex #(
    parameter BUFSIZE=0,
    parameter PREMATURE_BYTE=8'h33, COLT45_SHAKE=1
)( //TODO: Set address with parameters (or even config register with param defaults)!
    input clk, rst, ena,
    // DAS BUS
    input [11: 0] addra,
    input [ 3: 0] wea,
    input [31: 0] dina,
    output reg [31: 0] douta, // REGISTER like synchronous memory
    // DOS SHAKES POR FAVOR
    inout `BUS_SHAKE_type(8) RVA_RX, RVA_TX
);

    wire notwrite = !(|wea);

    // Forward patchwork (to UART ready/valid interfaces below):
    wire            Rx_Ready;   // OUT: We offer to take a byte
    wire            Rx_Valid;   // IN : UART announcing a byte
    wire [ 7: 0]    Rx_Data;    // IN : Data from UART
    wire [ 7: 0]    Tx_Data;    // OUT: Data to UART
    wire            Tx_Valid;   // OUT: We announce a byte
    wire            Tx_Ready;   // IN : UART can take a byte from us

    // Minimal statistics
    reg  [15: 0]    CNT_Rx, CNT_Tx;

// Shared across both implementation styles
    integer has_reset = 0; // For simulation
    always@(posedge clk) begin
        if (rst) begin
            CNT_Tx <= 0;
            CNT_Rx <= 0;
            douta <= 32'hFEEBDAED;
            if (!has_reset && COLT45_SHAKE) $display("MEMIO: Reset");
            has_reset <= 1'b1;
        end else has_reset = 0;
    end

generate if (BUFSIZE==0) begin:NOBUFF   // Direct Software-to-UART approach:

    // Set these up before the clock (continuous drive) so UART sees them within setup/detect time
    assign Rx_Ready = ena && notwrite && (addra===12'h003);
    assign Tx_Valid = ena && wea[0] && (addra===12'h002);
    assign Tx_Data  = (Tx_Valid) ? dina[7:0] : PREMATURE_BYTE;

    always@(posedge clk) begin
        if (rst) begin
            // Nothing unique here (generic reset above covers it)
        end else if (ena) begin
            douta <= 32'hFFFF_FFFF;
            case (addra)
                12'h000: if (notwrite) begin
                    if (COLT45_SHAKE && Tx_Ready) $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
                    douta  <= {31'b0, Tx_Ready};
                end
                12'h001: if (notwrite) begin
                    if (COLT45_SHAKE && Rx_Valid) $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
                    douta  <= {31'b0, Rx_Valid};
                end
                12'h002: if (wea[0]) begin
                    if (COLT45_SHAKE) $display("MEMIO: Tx Shake (%h, %d) CNT: %d   @%t", Tx_Data, Tx_Data, CNT_Tx+1, $time);
                    CNT_Tx <= CNT_Tx + 1;
                end
                12'h003: if (notwrite) begin
                    if (COLT45_SHAKE) $display("MEMIO: Rx Shake (%h, %d) CNT: %d  @%t", Rx_Data, Rx_Data, CNT_Rx+1, $time);
                    CNT_Rx <= CNT_Rx + 1;
                    douta <= {24'b0, Rx_Data};
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
            BUF_RxData  <= PREMATURE_BYTE; // Arbitrary flag to spot premature receive...
            BUF_TxData  <= PREMATURE_BYTE; // ...or xmit
        end else begin
            if (Rx_Ready && Rx_Valid) begin
                if (COLT45_SHAKE) $display("MEMIO: Rx Shake (%h, %d) CNT: %d   @%t", Rx_Data, Rx_Data, CNT_Rx+1, $time);
                BUF_RxData  <= Rx_Data;
                BUF_RxFull  <= 1;
                CNT_Rx <= CNT_Rx + 1;
            end

            if (Tx_Ready && Tx_Valid) begin
                if (COLT45_SHAKE) $display("MEMIO: Tx Shake (%h, %d) CNT: %d   @%t", Tx_Data, Tx_Data, CNT_Tx+1, $time);
                BUF_TxFull  <= 0;
                BUF_TxData  <= PREMATURE_BYTE; // Arbitrary value to spot double xmit errors
                CNT_Tx <= CNT_Tx + 1;
            end

            if (ena) begin
                douta <= 32'hFFFF_FFFF;
                case (addra)
                    12'h000: if (notwrite) begin
                        if (COLT45_SHAKE && (!BUF_TxFull && Tx_Ready)) $display("MEMIO: Poll Tx (%b) %b %b   @%t", Tx_Ready, !BUF_TxFull, Tx_Ready, $time);
                        douta <= {31'b0, !BUF_TxFull && Tx_Ready}; // Checking both maybe excessive?
                    end
                    12'h001: if (notwrite) begin
                        if (COLT45_SHAKE && BUF_RxFull) $display("MEMIO: Poll Rx (%b)   @%t", BUF_RxFull, $time);
                        douta <= {31'b0, BUF_RxFull};
                    end
                    12'h002: if (wea[0]) begin
                        if (COLT45_SHAKE) $display("MEMIO: Enqueue(%h, %d)   @%t", dina, dina, $time);
                        BUF_TxData  <= dina[7:0];
                        BUF_TxFull  <= 1;   // Don't check if already full, just overwrite with new value
                    end
                    12'h003: if (notwrite) begin
                        if (COLT45_SHAKE) $display("MEMIO: Dequeue (%h, %d)  @%t", BUF_RxData, BUF_RxData, $time);
                        douta       <= {24'b0, BUF_RxData};
                        BUF_RxFull  <= 0;
                    end
                endcase
            end
        end
    end

end endgenerate


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
