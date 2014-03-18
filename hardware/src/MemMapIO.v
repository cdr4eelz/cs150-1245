`include "cpuglobal.vh"

//TODO: Check for multiple reads/writes during stall???
//TODO: Translate address matches on "addra" into "one-hot" lines (maybe hierarchical)
//TODO-XTRA: Config address via registers/lines (simple, dedicated comparators)

/*                          Table 2: I/O Memory Map
ADDR-12 ADDRESS-32      FUNCTION        ACCESS  DATA-ENCODING/DESC
h000    32'h80000000    UART xmit cntl  Read    {31'b0, DataInReady}
h001    32'h80000004    UART recv cntl  Read    {31'b0, DataOutValid}
h002    32'h80000008    UART xmit data  Write   {24'b0, DataIn}
h003    32'h8000000c    UART recv data  Read    {24'b0, DataOut}
h004    32'h80000010    Cycle count     Read    Total number of cycles
h005    32'h80000014    Instr count     Read    Number of instructions executed
h006    32'h80000018    Reset counts    Write   N/A (any byte will trigger)
h014    32'h80000050    PF_FRAME        Write   PixelFeeder frame# (ADDR is frame# * 0x0040_0000)
h015    32'h80000054    GP_FRAME        Write   Stored, then "captured" along with GP_CODE on launch
h016    32'h80000058    GP_CODE         Write   Write also launches GraphicsProcessor
h017    32'h8000005C    Graphics cntl   Read    See Memory150 for concatenated signals
*/

module MemMapIO #(
    parameter BADNESS=1, BAD_WORD=32'hFED1C007, BAD_BYTE=8'h11,
    parameter COLT45_SHAKE=1, COLT45_POLLS=0
)(
    input clk, rst,
// DAS BUS:
    input           ena,    //ena is like "memory" style "enable port a"
    input  [11: 0]  addra,  //Address for read or write (use zero if worried about side effects)
    input  [ 3: 0]  wea,    //Write enable & byte mask together (ena must also be active for write)
    input  [31: 0]  dina,   //Data in grabbed at clock edge if enabled
    output reg [31:0] DOUTA,//DATA read (behaves like synchronous memory with registered output)
// DOS SHAKES POR FAVOR:
    inout `BUS_SHAKE_type(8) RVa_RX, RVa_TX,
    output RVa_RX_IRQ, RVa_TX_IRQ,
// Counter taps & reset pulse output:
    input  [31: 0] CNT_Cycle, CNT_Inst,
    output CNT_RESET_,
// PixelFeeder & GraphicsProcessor control:
    input  [31: 0] graphics_status,
    output [31: 0] PF_FRAME, GP_FRAME, GP_CODE,
    output PF_VALID, GP_VALID
);

    wire isWrite = ena && (wea != 4'b0000);
    wire isRead  = ena && (wea == 4'b0000);

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
        //NOTE:Avoid unnecessary resets --if (rst) {WAS_Rx_Valid,WAS_Tx_Ready} <= 0; else
        {WAS_Rx_Valid,WAS_Tx_Ready} <= {Rx_Valid,Tx_Ready};
    end
    assign RVa_RX_IRQ = (Rx_Valid && !WAS_Rx_Valid);
    assign RVa_TX_IRQ = (Tx_Ready && !WAS_Tx_Ready);

    // Drive these pre-clock (continuous drive) so other RVA sees them at clock
    assign Rx_Ready = isRead && (addra==12'h003);
    assign Tx_Valid = isWrite && (addra==12'h002);
    assign Tx_Data  = (BADNESS && !Tx_Valid) ? BAD_BYTE : dina[7:0];
    //NOTE:Loses a byte if Tx_Valid && !Tx_Ready
    //NOTE:Reads junk if Rx_Ready && !Rx_Valid


// Stats & Counters
//    reg  [31: 0] CNT_Rx, CNT_Tx; //Minimal IO statistics
    assign CNT_RESET_ = isWrite && (addra==12'h006);


// PixelFeeder & GraphicsController
    reg  [31: 0] reg_gpframe = 0; //Stash this internally, others just "pass through"
    always @(posedge clk) begin:_REG_GPFRAME_
        //NOTE:Avoid unnecessary resets --if (rst) reg_gpframe <= 0; else
        if (isWrite && (addra==12'h015)) reg_gpframe <= dina;
    end
    assign PF_VALID = (isWrite && (addra==12'h014));
    assign PF_FRAME = (BADNESS && !PF_VALID) ? BAD_WORD : dina;
    assign GP_VALID = (isWrite && (addra==12'h016));
    assign GP_FRAME = reg_gpframe; //(BADNESS && !GP_VALID) ? BAD_WORD : reg_gpframe;
    assign GP_CODE  = (BADNESS && !GP_VALID) ? BAD_WORD : dina;


// Reading operations
    reg [31:0] MUX_DOUTA;
    always @(*) begin:_MUX_DOUTA_
        case (addra) //Perform a read (value held until next read)
            12'h000: MUX_DOUTA = {31'd0, Tx_Ready};
            12'h001: MUX_DOUTA = {31'd0, Rx_Valid};
            12'h003: MUX_DOUTA = {24'd0, Rx_Data};
            12'h004: MUX_DOUTA = CNT_Cycle[31:0];
            12'h005: MUX_DOUTA = CNT_Inst[31:0];
            12'h017: MUX_DOUTA = graphics_status;
            default: MUX_DOUTA = (BADNESS) ? BAD_WORD : 32'd0;
        endcase
    end
    always @(posedge clk) begin:_REG_DOUTA_
        //NOTE:Avoid unnecessary resets -- if (rst) DOUTA <= 0; else
        if (isRead) DOUTA <= MUX_DOUTA;
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
            12'h000: if (COLT45_POLLS) $display("MEMIO: Poll Tx (%b)   @%t", Tx_Ready, $time);
            12'h001: if (COLT45_POLLS) $display("MEMIO: Poll Rx (%b)   @%t", Rx_Valid, $time);
            12'h003: $display("MEMIO: Rx Shake (0x%h, %d, '%c')   @%t", Rx_Data, Rx_Data, Rx_Data, $time);
            12'h004: $display("MEMIO: Read Cycles (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
            12'h005: $display("MEMIO: Read Steps (C=%d, S=%d)   @%t", CNT_Cycle, CNT_Inst, $time);
            default: $display("MEMIO: MISS-READ (%h)   @%t", addra, $time);
        endcase
        if (isWrite) case (addra)
            12'h002: $display("MEMIO: Tx Shake (0x%h, %d, '%c')  @%t", Tx_Data, Tx_Data, Tx_Data, $time);
            12'h006: $display("MEMIO: Counters reset. Were Cycles=%h Stalls=%h  @%t", CNT_Cycle, CNT_Inst, $time);
            //TODO: $display(...pix...)
            default: $display("MEMIO: MISS-WRITE (%h)   @%t", addra, $time);
        endcase
    end
endgenerate //COLT45_SHAKE
// synthesis translate_on

endmodule
