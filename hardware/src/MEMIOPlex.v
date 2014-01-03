`include "cpuglobal.vh"

//TODO: All memories through here
//TODO: RVA as easily duplicated submodule
//TODO: Config address via registers/lines (simple, dedicated comparators)

module MEMIOPlex #(
    parameter PREMATURE_BYTE=8'h3E, COLT45_SHAKE=0
)(
    input clk, rst,

    // DAS BUS
    input ena, //ena is like "memory" style "enable port a"
    input [11: 0] addra, //Address for read or write (use zero if worried about side effects)
    input [ 3: 0] wea, //Write enable byte mask together
    input [31: 0] dina, //Data in grabbed at clock edge if enabled
    output reg [31: 0] DOUTA, // REGISTER out (treat like synchronous memory)

    // DOS SHAKES POR FAVOR
    inout `BUS_SHAKE_type(8) RVa_RX, RVa_TX,

    // Counter taps & reset
    input [31: 0] CNT_Cycle, CNT_Inst,
    output CNT_RESET_
);

    wire isWrite = ena && (|wea);
    wire isRead = ena && !(|wea);

//RVA-Pair operations
    // Forward patchwork (individual ready/valid lines to consolidated RVA SHAKE below):
    wire            Rx_Ready;   // OUT: We offer to take a byte
    wire            Rx_Valid;   // IN : UART announcing a byte
    wire [ 7: 0]    Rx_Data;    // IN : Data from UART
    wire [ 7: 0]    Tx_Data;    // OUT: Data to UART
    wire            Tx_Valid;   // OUT: We announce a byte
    wire            Tx_Ready;   // IN : UART can take a byte from us
    // Drive these pre-clock (continuous drive) so other RVA sees them at clock
    assign Rx_Ready = isRead && (addra==12'h003);
    assign Tx_Valid = isWrite && (addra==12'h002);
    assign Tx_Data  = (Tx_Valid) ? dina[7:0] : PREMATURE_BYTE;

    // Stats & Counters
//    reg  [31: 0] CNT_Rx, CNT_Tx; //Minimal IO statistics

    assign CNT_RESET_ = isWrite && (addra==12'h018);

/* if (COLT45_SHAKE) begin
            if (isRead) case (addra)
                12'h000: $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
                12'h001: $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
                12'h003: $display("MEMIO: Rx Shake (0x%h, %d, '%c')   @%t", Rx_Data, Rx_Data, Rx_Data, $time);
                12'h010: $display("MEMIO: Read Cycles (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
                12'h014: $display("MEMIO: Read Steps (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
            endcase
            if (isWrite) case (addra)
                12'h002: $display("MEMIO: Tx Shake (0x%h, %d, '%c')  @%t", Tx_Data, Tx_Data, Tx_Data, $time);
                12'h018: $display("MEMIO: Counters reset. Were Cycles=%h Stalls=%h  @%t", CNT_Cycle, CNT_Inst, $time);
            endcase
*/

    reg [31:0] MUX_DOUTA;
    always @(*) begin:_MUX_DOUTA_
        MUX_DOUTA = 0;
        case (addra) //Perform a read (value held until next read)
            12'h000: MUX_DOUTA = {31'b0, Tx_Ready};
            12'h001: MUX_DOUTA = {31'b0, Rx_Valid};
            12'h003: MUX_DOUTA = {24'b0, Rx_Data};
            12'h010: MUX_DOUTA = CNT_Cycle;
            12'h014: MUX_DOUTA = CNT_Inst;
        endcase
    end
    always @(posedge clk) begin:_REG_DOUTA_
        if (rst) DOUTA <= 0;
        else if (isRead) DOUTA <= MUX_DOUTA;
    end


    BUS_SHAKE_tap #(.InWidth(8)) TAP_SHAKE_Rx
    ( ._BUS_(RVa_RX), //Incoming
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );

    BUS_SHAKE_tun #(.InWidth(8)) TUN_SHAKE_Tx
    ( ._BUS_(RVa_TX), //Outgoing
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );

endmodule
