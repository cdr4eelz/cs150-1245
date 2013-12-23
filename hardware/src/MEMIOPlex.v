`include "cpuglobal.vh"

module MEMIOPlex #(
    parameter PREMATURE_BYTE=8'h33, COLT45_SHAKE=0
    //TODO: Config address via parameters (or live with config registers/lines)
)(
    input clk, rst, ena, //Standard synchronous "memory" kinda stuff
    // DAS BUS
    input [11: 0] addra, //Address for read or write (use zero if worried about side effects)
    input [ 3: 0] wea, //Write enable byte mask together
    input [31: 0] dina, //Data in grabbed at clock edge if enabled
    output reg [31: 0] douta, // REGISTER out (treat like synchronous memory)

    // DOS SHAKES POR FAVOR
    inout `BUS_SHAKE_type(8) RVA_RX, RVA_TX
);

    wire notwrite = !(|wea); //Like a isRead signal (almost)!

//RVA-Pair operations
    // Forward patchwork (individual ready/valid lines to consolidated RVA SHAKE below):
    wire            Rx_Ready;   // OUT: We offer to take a byte
    wire            Rx_Valid;   // IN : UART announcing a byte
    wire [ 7: 0]    Rx_Data;    // IN : Data from UART
    wire [ 7: 0]    Tx_Data;    // OUT: Data to UART
    wire            Tx_Valid;   // OUT: We announce a byte
    wire            Tx_Ready;   // IN : UART can take a byte from us
    // Minimal statistics
    reg  [15: 0]    CNT_Rx, CNT_Tx;
    always@(posedge clk) begin
        if (rst) begin
            CNT_Tx <= 16'd0;
            CNT_Rx <= 16'd0;
        end
    end
    // Drive these pre-clock (continuous drive) so other RVA sees them at clock
    assign Rx_Ready = ena && notwrite && (addra==12'h003);
    assign Tx_Valid = ena && wea[0] && (addra==12'h002);
    assign Tx_Data  = (Tx_Valid) ? dina[7:0] : PREMATURE_BYTE;


    always@(posedge clk) begin
        if (rst) begin
        end else if (ena) case (addra) //ena might not apply to everything later (double-check)
            12'h000: if (notwrite) begin
                if (COLT45_SHAKE && Tx_Ready) $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
                douta  <= {31'b0, Tx_Ready};
            end
            12'h001: if (notwrite) begin
                if (COLT45_SHAKE && Rx_Valid) $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
                douta  <= {31'b0, Rx_Valid};
            end
            12'h002: if (wea[0]) begin
                if (COLT45_SHAKE) $display("MEMIO: Tx Shake (0x%h, %d, '%c') CNT: %d   @%t", Tx_Data, Tx_Data, Tx_Data, CNT_Tx+1, $time);
                CNT_Tx <= CNT_Tx + 1;
            end
            12'h003: if (notwrite) begin
                if (COLT45_SHAKE) $display("MEMIO: Rx Shake (0x%h, %d, '%c') CNT: %d  @%t", Rx_Data, Rx_Data, Rx_Data, CNT_Rx+1, $time);
                CNT_Rx <= CNT_Rx + 1;
                douta <= {24'b0, Rx_Data};
            end
        endcase
    end


    BUS_SHAKE_tap #(.InWidth(8)) TAP_SHAKE_Rx
    ( ._BUS_(RVA_RX), //Incoming
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );

    BUS_SHAKE_tun #(.InWidth(8)) TUN_SHAKE_Tx
    ( ._BUS_(RVA_TX), //Outgoing
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );

endmodule
