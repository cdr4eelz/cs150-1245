`include "CPUBusses.vh"

module MEMIOPlex #(
    parameter BUFSIZE=0, SANITY=0,
    parameter PREMATURE_BYTE=8'h33, COLT45_POLL=0, COLT45_SHAKE=1
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

    localparam _MAGIC_SANE_ = 15'h7DE3; //NOTE: Sanity might help since talks to outside world
generate if (SANITY) begin:_SANITY_
    //TODO: Mute the UART somewhere until _SANE_
    //TODO: Perhaps can just have a shared _SANE_ line in CPUGlobals
    reg [14:0] MAGIC_SANE_; //TODO: Use FPGA initializer that intentionally doesn't match
    always@(posedge clk) if (rst) MAGIC_SANE_ <= _MAGIC_SANE_;
    wire _SANE_ = (MAGIC_SANE_ == _MAGIC_SANE_);
end else begin:_INSULANT_
    wire _SANE_ = 1'b1;
end endgenerate

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

generate if (BUFSIZE==0) begin:NOBUFF   // Direct Software-to-UART approach:

    // Set these up before the clock (continuous drive) so UART sees them within setup/detect time
    assign Rx_Ready = ena && notwrite && (addra===12'h003);
    assign Tx_Valid = ena && wea[0] && (addra===12'h002);
    assign Tx_Data  = (Tx_Valid) ? dina[7:0] : PREMATURE_BYTE;

    always@(posedge clk) begin
        if (rst) begin
            CNT_Tx <= 0;
            CNT_Rx <= 0;
            douta <= 32'hFEEBDAED;
            if (COLT45_SHAKE) $display("MEMIO: Reset");
        end else if (ena) begin
            douta <= 32'hFFFF_FFFF;
            case (addra)
                12'h000: if (notwrite) begin
                    if (COLT45_SHAKE && Tx_Ready) $display("MEMIO: Poll Tx (%b)", Tx_Ready);
                    douta  <= {31'b0, Tx_Ready};
                end
                12'h001: if (notwrite) begin
                    if (COLT45_SHAKE && Rx_Valid) $display("MEMIO: Poll Rx (%b)", Rx_Valid);
                    douta  <= {31'b0, Rx_Valid};
                end
                12'h002: if (wea[0]) begin
                    if (COLT45_SHAKE) $display("MEMIO: Tx Shake (%h, %d) CNT: %d", Tx_Data, Tx_Data, CNT_Tx+1);
                    CNT_Tx <= CNT_Tx + 1;
                end
                12'h003: if (notwrite) begin
                    if (COLT45_SHAKE) $display("MEMIO: Rx Shake (%h, %d) CNT: %d", Rx_Data, Rx_Data, CNT_Rx+1);
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
            BUF_RxData  <= 8'h97;   // Arbitrary flag to spot premature receive...
            BUF_TxData  <= 8'h98;   // ...or xmit
            douta <= 32'hFEEBDAED;
            if (COLT45_SHAKE) $display("MEMIO: Reset");
        end else begin
            if (Rx_Ready && Rx_Valid) begin
                if (COLT45_SHAKE) $display("MEMIO: Rx Shake (%h)", Rx_Data);
                BUF_RxData  <= Rx_Data;
                BUF_RxFull  <= 1;
            end

            if (Tx_Ready && Tx_Valid) begin
                if (COLT45_SHAKE) $display("MEMIO: Tx Shake (%h)", Tx_Data);
                BUF_TxFull  <= 0;
                BUF_TxData  <= 8'h99;   // Arbitrary value to spot double xmit errors
            end

            if (ena && notwrite) case (addra)
                12'h000: douta <= {31'b0, !BUF_TxFull && Tx_Ready}; // Checking both maybe excessive?
                12'h001: douta <= {31'b0, BUF_RxFull};  // TODO: Could we safely OR with real UART rx?
    //          12'h002: douta <= {24'b0, BUF_TxData};  // Read back last written but unsent value, just for fun
                12'h003: begin  // Read from our mini-buffer (and indicate that there is room)
                    douta       <= {24'b0, BUF_RxData};
                    BUF_RxFull  <= 0;
                end
            endcase

            if (ena && wea[0]) case (addra)   // Avoid zero writes if doing sb or sh near but not ON low byte
                12'h002: begin
                    if (COLT45_SHAKE) $display("MEMIO: Write queued (%h)", dina);
                    BUF_TxData  <= dina[7:0];
                    BUF_TxFull  <= 1;   // Don't check if already full, just overwrite with new value
                end
            endcase
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
