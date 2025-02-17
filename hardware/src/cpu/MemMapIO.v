`include "../cpuglobal.vh"

module MemMapIO #(
    parameter BADNESS=0, BAD_WORD=32'hFED1C007, BAD_BYTE=8'h11,
    parameter COLT45_SHAKE=1, COLT45_POLLS=0
)(
    input clk, rst, stall,

// DAS BUS:
    input         ena,    //ena is like "memory" style "enable port a"
    input  [11:0] addra,  //Address for read or write (use zero if worried about side effects)
    input  [ 3:0] wea,    //Write enable & byte mask together (ena must also be active for write)
    input  [31:0] dina,   //Data in grabbed at clock edge if enabled
    output reg [31:0] douta,//DATA read (behaves like synchronous memory with registered output)

// UART ins & outs:
    output          Rx_Ready,   // OUT: We offer to take a byte
    input           Rx_Valid,   // IN : UART announcing a byte
    input  [7:0]    Rx_Data,    // IN : Data from UART
    output [7:0]    Tx_Data,    // OUT: Data to UART
    output          Tx_Valid,   // OUT: We announce a byte
    input           Tx_Ready,   // IN : UART can take a byte from us

// GPU control:
    output          pf_vframe,  gp_vcode,  gp_vframe,
    output [ 31:0]  pf_wframe,  gp_wcode,  gp_wframe,
    input  [ 31:0]              gp_rcode,
    input  [ 15:0]  pf_status,             gp_status
);

//                  Table 2: I/O Memory Map
//ADDR-12 ADDRESS-32      FUNCTION                      ACCESS
localparam [5:0]            //   DATA-ENCODING/DESC
//h000    32'h80000000    UART xmit cntl                Read
    A_D0TxReady     =6'h00, // {31'b0, DataInReady}
//h001    32'h80000004    UART recv cntl                Read
    A_D0RxValid     =6'h01, // {31'b0, DataOutValid}
//h002    32'h80000008    UART xmit data                Write
    A_D0TxData      =6'h02, // {24'b0, DataIn}
//h003    32'h8000000c    UART recv data                Read
    A_D0RxData      =6'h03, // {24'b0, DataOut}
//h004    32'h80000010    Cycle count                   Read
    A_CntCycle      =6'h04, // Total number of cycles
//h005    32'h80000014    Instr count                   Read
    A_CntInst       =6'h05, // Number of instructions executed
//h006    32'h80000018    Reset counts                  Write
    A_ResetCnt      =6'h06, // N/A (any byte will trigger)
//h014    32'h80000050    PF_FRAME                      Write
    A_PFFrame       =6'h14, // PixelFeeder frame# (ADDR is frame# * 0x0040_0000)
//h015    32'h80000054    GP_FRAME                      Write
    A_GPFrame       =6'h15, // Stored, then "captured" along with GP_CODE on launch
//h016    32'h80000058    GP_CODE                       Write
    A_GPCode        =6'h16, // Write also launches GraphicsProcessor
//h017    32'h8000005C    GPU status                    Read
    A_GPUStatus     =6'h17; // See Memory150 for concatenated signals
//
//[Maps onto multiple addresses to reduce # of address lines checked]
    localparam H_D0TxReady = 0,   H_D0RxValid = 1,   H_D0TxData  = 2,
               H_D0RxData  = 3,   H_CntCycle  = 4,   H_CntInst   = 5,
               H_ResetCnt  = 6,   H_PFFrame   = 7,   H_GPFrame   = 8,
               H_GPCode    = 9,   H_GPUStatus =10;
    localparam H__LAST = H_GPUStatus;

    wire isWrite = (ena &&  |wea); // != 4'b0000
    wire isRead  = (ena && ~|wea); // == 4'b0000

    reg  [(H__LAST-1):0] HOT_ADDR;
    always @(*) begin:_HOT_ADDR_
        case (addra[5:0])
            A_D0TxReady : HOT_ADDR = (1 << H_D0TxReady);
            A_D0RxValid : HOT_ADDR = (1 << H_D0RxValid);
            A_D0TxData  : HOT_ADDR = (1 << H_D0TxData);
            A_D0RxData  : HOT_ADDR = (1 << H_D0RxData);
            A_CntCycle  : HOT_ADDR = (1 << H_CntCycle);
            A_CntInst   : HOT_ADDR = (1 << H_CntInst);
            A_ResetCnt  : HOT_ADDR = (1 << H_ResetCnt);
            A_PFFrame   : HOT_ADDR = (1 << H_PFFrame);
            A_GPFrame   : HOT_ADDR = (1 << H_GPFrame);
            A_GPCode    : HOT_ADDR = (1 << H_GPCode);
            A_GPUStatus : HOT_ADDR = (1 << H_GPUStatus);
            default: HOT_ADDR = 0;
        endcase
    end

    // Drive these pre-clock (continuous drive) so other RVA sees them at clock
    assign Rx_Ready = isRead && HOT_ADDR[H_D0RxData]; //(addra==12'h003)
    assign Tx_Valid = isWrite && HOT_ADDR[H_D0TxData]; //(addra==12'h002)
    assign Tx_Data  = (BADNESS && !Tx_Valid) ? BAD_BYTE : dina[7:0];
    //NOTE:Loses a byte if Tx_Valid && !Tx_Ready
    //NOTE:Reads junk if Rx_Ready && !Rx_Valid


// Stats & Counters
//  reg  [31: 0] CNT_Rx, CNT_Tx; //Minimal IO statistics
    reg  [31: 0] CNT_Cycle, CNT_Inst;
    wire rst_CNT = (isWrite && HOT_ADDR[H_ResetCnt]);
    always @(posedge clk) begin:_REG_CNT_
        if (rst | rst_CNT) begin
            {CNT_Cycle, CNT_Inst} <= 0;
        end else begin
            CNT_Cycle <= CNT_Cycle+1;
            if (!stall) CNT_Inst <= CNT_Inst+1;
        end
    end

// PixelFeeder & GraphicsController
    reg          pf_vframe_r, gp_vframe_r, gp_vcode_r;
    reg  [31: 0] pf_wframe_r, gp_wframe_r, gp_wcode_r;
    reg  [31: 0] gpu_status_r;
    //Stash these internally for isolation (trade latency)
    always @(posedge clk) begin:_REG_GPU_
        if (isWrite && HOT_ADDR[H_PFFrame]) begin
            pf_wframe_r <= dina;
            pf_vframe_r <= 1'b1;
        end else pf_vframe_r <= 1'b0;
        if (isWrite && HOT_ADDR[H_GPFrame]) begin
            gp_wframe_r <= dina;
            gp_vframe_r <= 1'b1;
        end else gp_vframe_r <= 1'b0;
        if (isWrite && HOT_ADDR[H_GPCode])  begin
          gp_wcode_r  <= dina;
          gp_vcode_r <= 1'b1;
        end else gp_vcode_r <= 1'b0;

        //  1-cycle latency (don't check too quick after trigger)!
        gpu_status_r <= { pf_status, gp_status };
    end
    assign pf_wframe = pf_wframe_r, pf_vframe = pf_vframe_r;
    assign gp_wframe = gp_wframe_r, gp_vframe = gp_vframe_r;
    assign gp_wcode  = gp_wcode_r,  gp_vcode  = gp_vcode_r;


// Reading operations
    reg [31:0] MUX_DOUTA;
    always @(*) begin:_MUX_DOUTA_ //Perform a read (value held until next read)
        case (addra[5:0])
            A_D0TxReady : MUX_DOUTA = {31'd0, Tx_Ready};
            A_D0RxValid : MUX_DOUTA = {31'd0, Rx_Valid};
            //A_D0RxData
            A_D0RxData  : MUX_DOUTA = {24'd0, Rx_Data};
            A_CntCycle  : MUX_DOUTA = CNT_Cycle[31:0];
            A_CntInst   : MUX_DOUTA = CNT_Inst[31:0];
            //A_ResetCnt,A_PFFrame,A_GPFrame,A_GPCode
            A_GPUStatus : MUX_DOUTA = gpu_status_r;
            default: MUX_DOUTA = (BADNESS) ? BAD_WORD : 32'dx;
        endcase
    end
    always @(posedge clk) begin:_REG_DOUTA_
        //NOTE:Avoiding unnecessary resets -- if (rst) DOUTA <= 0; else
        if (isRead) douta <= MUX_DOUTA;
    end


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
