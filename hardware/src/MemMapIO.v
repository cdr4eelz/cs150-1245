`include "cpuglobal.vh"

//TODO: Check for multiple reads/writes during stall???
//TODO-XTRA: Config address via registers/lines (simple, dedicated comparators)

module MemMapIO #(
    parameter BADNESS=1, BAD_WORD=32'hFED1C007, BAD_BYTE=8'h11,
    parameter COLT45_SHAKE=1
)(
    input clk, rst,

    // DAS BUS
    input ena, //ena is like "memory" style "enable port a"
    input [11: 0] addra, //Address for read or write (use zero if worried about side effects)
    input [ 3: 0] wea, //Write enable & byte mask together (ena must also be active for write)
    input [31: 0] dina, //Data in grabbed at clock edge if enabled
    output reg [31: 0] DOUTA, // REGISTER out (treat like synchronous memory)

    // DOS SHAKES POR FAVOR
    inout `BUS_SHAKE_type(8) RVa_RX, RVa_TX,
    output RVa_RX_IRQ, RVa_TX_IRQ,

    // Counter taps & reset
    input [31: 0] CNT_Cycle, CNT_Inst,
    output CNT_RESET_
);

    wire isWrite = ena && (wea != 4'b0000);
    wire isRead = ena && (wea == 4'b0000);

//RVA-Pair operations
    // Forward patchwork (individual ready/valid lines to consolidated RVA SHAKE below):
    wire            Rx_Ready;   // OUT: We offer to take a byte
    wire            Rx_Valid;   // IN : UART announcing a byte
    wire [ 7: 0]    Rx_Data;    // IN : Data from UART
    wire [ 7: 0]    Tx_Data;    // OUT: Data to UART
    wire            Tx_Valid;   // OUT: We announce a byte
    wire            Tx_Ready;   // IN : UART can take a byte from us

    // Prior clock state for "edge" -> "pulse" conversion
    reg WAS_Rx_Valid, WAS_Tx_Ready;
    always @(posedge clk) begin:_REG_WAS_
        if (rst) {WAS_Rx_Valid,WAS_Tx_Ready} <= 0;
        else {WAS_Rx_Valid,WAS_Tx_Ready} <= {Rx_Valid,Tx_Ready};
    end
    assign RVa_RX_IRQ = (Rx_Valid && !WAS_Rx_Valid);
    assign RVa_TX_IRQ = (Tx_Ready && !WAS_Tx_Ready);

    // Drive these pre-clock (continuous drive) so other RVA sees them at clock
    assign Rx_Ready = isRead && (addra==12'h003);
    assign Tx_Valid = isWrite && (addra==12'h002);
    assign Tx_Data  = (BADNESS && Tx_Valid) ? dina[7:0] : BAD_BYTE;
    //Loses a byte if Tx_Valid && !Tx_Ready
    //Reads junk if Rx_Ready && !Rx_Valid

    // Stats & Counters
//    reg  [31: 0] CNT_Rx, CNT_Tx; //Minimal IO statistics
    assign CNT_RESET_ = isWrite && (addra==12'h006);


    reg [31:0] MUX_DOUTA;
    always @(*) begin:_MUX_DOUTA_
        case (addra) //Perform a read (value held until next read)
            12'h000: MUX_DOUTA = {31'd0, Tx_Ready};
            12'h001: MUX_DOUTA = {31'd0, Rx_Valid};
            12'h003: MUX_DOUTA = {24'd0, Rx_Data};
            12'h004: MUX_DOUTA = CNT_Cycle[31:0];
            12'h005: MUX_DOUTA = CNT_Inst[31:0];
            default: MUX_DOUTA = BAD_WORD;
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


// synthesis translate_off
generate if (COLT45_SHAKE)
    always @(posedge clk) begin:_SHAKE_MSG_
        if (isRead) case (addra)
            12'h000: $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
            12'h001: $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
            12'h003: $display("MEMIO: Rx Shake (0x%h, %d, '%c')   @%t", Rx_Data, Rx_Data, Rx_Data, $time);
            12'h004: $display("MEMIO: Read Cycles (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
            12'h005: $display("MEMIO: Read Steps (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
            default: $display("MEMIO: MISS-READ (%h)   @%t", addra, $time);
        endcase
        if (isWrite) case (addra)
            12'h002: $display("MEMIO: Tx Shake (0x%h, %d, '%c')  @%t", Tx_Data, Tx_Data, Tx_Data, $time);
            12'h006: $display("MEMIO: Counters reset. Were Cycles=%h Stalls=%h  @%t", CNT_Cycle, CNT_Inst, $time);
            default: $display("MEMIO: MISS-WRITE (%h)   @%t", addra, $time);
        endcase
    end
endgenerate //COLT45_SHAKE
// synthesis translate_on

endmodule
