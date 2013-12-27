`include "cpuglobal.vh"

module MEMIOPlex #(
    parameter PREMATURE_BYTE=8'h3E, COLT45_SHAKE=0
    //TODO: Config address via parameters (or live with config registers/lines)
)(
    input clk, rst, stall, //NOTE:stall doesn't automatically override "ena"

    // DAS BUS
    input ena, //ena is like "memory" style "enable port a"
    input [11: 0] addra, //Address for read or write (use zero if worried about side effects)
    input [ 3: 0] wea, //Write enable byte mask together
    input [31: 0] dina, //Data in grabbed at clock edge if enabled
    output reg [31: 0] douta, // REGISTER out (treat like synchronous memory)

    // DOS SHAKES POR FAVOR
    inout `BUS_SHAKE_type(8) RVa_RX, RVa_TX
);

    wire isWrite = (|wea); //TODO: Do we check "ena" for write???
    wire isRead = ena && !isWrite;

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
    assign Tx_Valid = isWrite && wea[0] && (addra==12'h002);
    assign Tx_Data  = (Tx_Valid) ? dina[7:0] : PREMATURE_BYTE;

    // Stats & Counters
    reg  [31: 0] CNT_Rx, CNT_Tx; //Minimal IO statistics
    reg  [31: 0] CycleCount, StepCount, nextCycle, nextStep;

    always@(*) begin
        nextCycle = CycleCount+1;
        nextStep = StepCount+(~stall);
        if (isWrite && (addra==12'h018)) begin
            {nextCycle, nextStep} = 0;
        end
    end

    always@(posedge clk) begin
        if (rst) begin
            douta <= 0;
            {CNT_Rx, CNT_Tx} <= 0;
            {CycleCount, StepCount} <= 0;
        end else begin
            {CycleCount, StepCount} <= {nextCycle, nextStep}; //Update performance counters

            if (isWrite) case (addra)
                12'h002: begin //Just our debug & stats here (write happens from RVA signals)
                    if (COLT45_SHAKE) $display("MEMIO: Tx Shake (0x%h, %d, '%c') CNT: %d   @%t", Tx_Data, Tx_Data, Tx_Data, CNT_Tx+1, $time);
                    CNT_Tx <= CNT_Tx + 1;
                end
            endcase

            if (isRead) case (addra) //Perform a read (value held until next read)
                12'h000: begin
                    if (COLT45_SHAKE && Tx_Ready) $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
                    douta  <= {31'b0, Tx_Ready};
                end
                12'h001: begin
                    if (COLT45_SHAKE && Rx_Valid) $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
                    douta  <= {31'b0, Rx_Valid};
                end
                12'h003: begin
                    if (COLT45_SHAKE) $display("MEMIO: Rx Shake (0x%h, %d, '%c') CNT: %d  @%t", Rx_Data, Rx_Data, Rx_Data, CNT_Rx+1, $time);
                    CNT_Rx <= CNT_Rx + 1;
                    douta <= {24'b0, Rx_Data};
                end
                12'h010: douta <= CycleCount;
                12'h014: douta <= StepCount;
                default: douta <= 0;
            endcase

        end
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
