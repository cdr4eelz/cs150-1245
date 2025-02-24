`include "../cpuglobal.vh"

module MemBank #(
    parameter CPU_FREQ = 50_000_000,
    parameter BAUD_RATE =   115_200,
    parameter [31:0] DEAD_DMEM = 32'd0, DEAD_IMEM = 32'd0,
    parameter XTRA_IMEM = 1, XTRA_DMEM = 1, //Scratchpad extra block-rams
    parameter DD=`COLT45_DD,
    parameter COLT45_SCRATCH=0, COLT45_MEMWRITE=0
)(
    input   clk, rst, stall,

// Memory/IO lines (snagged from MIPS150):
    input  [31: 0]  IMEM_ADDR, DMEM_ADDR,
    output [31: 0]  IMEM_DATA, DMEM_DATA,
    input           MemToRegDX_, MemWriteDX_, PCinBIOSDX_, //TODO:Rename
    input  [31: 0]  _WDataMasked, //TODO:Rename
    input  [ 3: 0]  _WriteMask,

// Serial (UART):
    input   SerialRX,
    output  SerialTX,

// Interrupts:
    output irq_uart0, irq_uart1,

// Memory Caches:
    output [ 31:0]  dcache_addr,  icache_addr,
    output [  3:0]  dcache_we,    icache_we,
    output          dcache_re,    icache_re,
    output [ 31:0]  dcache_din,   icache_din,
    input  [ 31:0]  dcache_dout,  icache_dout,

// GPU control:
    output          pf_vframe,  gp_vcode, gp_vframe,
    output [ 31:0]  pf_wframe,  gp_wcode, gp_wframe,
    input  [ 31:0]              gp_rcode,
    input  [ 15:0]  pf_status,            gp_status
);

//TODO: Ideally generate "isRead/isWrite" signals WHILE generating _WriteMask

    reg  [3:0] hoti_;
    always @(*) begin:_MUX_HOTI_ //Drive appropriate "activate" line for instruction fetch
        case (IMEM_ADDR[31:28])
            4'b1100: hoti_ = 4'b1000;       //0xC => ISR
            4'b0100: hoti_ = 4'b0100;       //0x4 => BR
            4'b0001: hoti_ = 4'b0010;       //0x1 => IC
            4'b0110: hoti_ = (XTRA_IMEM)?4'b0001:0; //XTRA: 0x6 => IB (Scratch-IMEM)
            default: hoti_ = 0;
        endcase
    end
    //Not all instruction-fetch "drives" usable by memories (several are always enabled)
    wire hoti_BR_  = hoti_[2]; //TODO: Consider this for PCinBIOS test
    wire hoti_IC_  = hoti_[1];

    reg _hot_IO, _hot_BR, _hot_DC, _hot_IC, _hot_ISR;
    reg _hot_IB, _hot_DB;
    always @(*) begin  //TODO: Figure out if OK to drive "reg" in always@(*)!!!
        {_hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR} = 0;
        if (MemToRegDX_ || MemWriteDX_) begin
            case (DMEM_ADDR[31:28])
                4'b1000: _hot_IO = 1'b1;                        //  0x8
                4'b0100: _hot_BR = !MemWriteDX_;        //Read-only 0x4
                4'b0011: begin  // Writes same value to DC+IC       0x3
                        _hot_DC = 1'b1;
                        _hot_IC = MemWriteDX_ && PCinBIOSDX_;
                    end
                4'b0010: _hot_IC = MemWriteDX_ && PCinBIOSDX_;  //  0x2
                4'b0001: _hot_DC = 1'b1;                        //  0x1
                4'b0110: _hot_IB = XTRA_IMEM && 1'b1; //MemWriteDX_; //XTRA:Scratch-IMEM 0x6
                4'b0101: _hot_DB = XTRA_IMEM && 1'b1;        //XTRA:Scratch-DMEM 0x5
                4'b1100: _hot_ISR = 1'b1; //MemWriteDX_; //ISR// 0xC
            endcase
        end
    end


    reg         P_dcache_re;
    reg  [31:0] P_dcache_addr;
    reg  [ 3:0] P_hoti;
    reg  [ 3:0] P_selD;
    always @(posedge clk) begin:_REG_PRIOR_
        P_dcache_re <= dcache_re;
        P_dcache_addr <= dcache_addr;
        if (!stall) begin
            P_hoti <= hoti_;
            P_selD <= DMEM_ADDR[31:28];
        end
    end


    wire [31: 0] INST_ISR, INST_BR, INST_IC, INST_IB;
    reg  [31: 0] MUX_IMEM;
    always @(*) begin:_MUX_IMEM_ //Drive instruction from appropriate memory component
        case (P_hoti)
            4'b1000: MUX_IMEM = INST_ISR;       //0xC => ISR   These are "one-hot" bits...
            4'b0100: MUX_IMEM = INST_BR;        //0x4 => BR      so case match values don't...
            4'b0010: MUX_IMEM = INST_IC;        //0x1 => IC      correlate with high-nibble.
            4'b0001: MUX_IMEM = (XTRA_IMEM)?INST_IB:DEAD_IMEM;//XTRA:  0x6 => IB (Scratch-IMEM)
            default: MUX_IMEM = DEAD_IMEM; //TODO: Make "HALT" instruction rather than "NOP"
        endcase
    end
    assign IMEM_DATA = MUX_IMEM;


    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB, RData_IB, RData_ISR;
    reg  [31: 0] MUX_DMEM;
    always @(*) begin:_MUX_DMEM_
        case (P_selD)
            4'b1000: MUX_DMEM = RData_IO;                       //  0x8
            4'b0100: MUX_DMEM = RData_BR;                       //  0x4
            4'b0011: MUX_DMEM = RData_DC;                       //  0x3
            4'b0001: MUX_DMEM = RData_DC;                       //  0x1
            4'b0101: MUX_DMEM = (XTRA_DMEM)?RData_DB:DEAD_DMEM;//XTRA: Scratchpad-DMEM  0x5
            4'b0110: MUX_DMEM = (XTRA_IMEM)?RData_IB:DEAD_DMEM;//XTRA: Scratchpad-IMEM  0x6
            4'b1100: MUX_DMEM = RData_ISR;                      //  0xC
            default: MUX_DMEM = DEAD_DMEM;
        endcase // CAUTIOUS trapping of EVERY case
    end
    assign DMEM_DATA = MUX_DMEM;


    // MEMORY/MMIO ELEMENTS

    //NOTE: DRAM rollsover at 0x0200_0000 but not imposing limit in CPU (just top nibble)
    assign dcache_addr = (stall) ? P_dcache_addr : {4'h0, DMEM_ADDR[27:0]},
        dcache_we   = (!stall && _hot_DC) ? (_WriteMask) : 4'b0000,
        dcache_din  = _WDataMasked,
        dcache_re   = (stall) ? P_dcache_re : (/*!stall &&*/ _hot_DC) && (_WriteMask == 4'b0000),
        RData_DC    = dcache_dout;
//    assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0, RData_DC=32'd0;

    //NOTE: Both _hot_DC && _hot_IC ARE allowed to be active simultaneously for WRITE
    //      but writability rules prevent INST-read & DATA-write collision
    assign icache_addr = {4'h0, (hoti_IC_) ? IMEM_ADDR[27:0] : DMEM_ADDR[27:0]},
        icache_we   = (!stall && !hoti_IC_ && _hot_IC) ? (_WriteMask) : 4'b0000,
        icache_din  = _WDataMasked,
        icache_re   = (!stall && hoti_IC_),
        INST_IC     = icache_dout;
//    assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0, INST_IC=32'd0;


//    bios_mem_24 bram_bios
//    (   .clk(clk),  .ena(!stall && _hot_BR),
//        .addra(DMEM_ADDR[13:2]),
//        .douta(RData_BR),//OUT-32
//        .enb(hoti_BR_),
//        .addrb(IMEM_ADDR[13:2]),
//        .doutb(INST_BR)
//    );
    bios_mem bram_bios
    ( .clka(clk), .ena(!stall && _hot_BR),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/
    // Instruction reading port (b)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_BR_), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

//    dmem_24 bram_dmem
//    (   .clk(clk),  .en(!stall && _hot_DB),
//        .addr(DMEM_ADDR[15:2]),  //input [13:0]
//        .dout(RData_DB),//OUT-32
//        .we(_WriteMask),  .din(_WDataMasked)
//    );
    dmem_blk_mem bram_dmem
    ( .clka(clk), .ena(!stall && _hot_DB),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_DB),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked)
    ) /* synthesis syn_noprune=1 */;

//    imem_24 bram_imem
//    (   .clk(clk), .ena(!stall && _hot_IB),
//        .addra(DMEM_ADDR[15:2]),  //input [13:0]
//        .wea(_WriteMask),  .dina(_WDataMasked),
//        .addrb(IMEM_ADDR[15:2]),  //input [13:0]
//        .doutb(INST_IB)
//    );
    imem_blk_mem bram_imem
    ( .clka(clk), .ena(!stall && _hot_IB),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_IB),  //OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
    // INSTRUCTION Fletch (sic :)
      .clkb(clk),   .addrb(IMEM_ADDR[13:2]),
      .enb(1'b1),   .web(4'b0000), 
      .dinb(32'd0), .doutb(INST_IB)
    ) /* synthesis syn_noprune=1 */;

//    imem_24 bram_isr
//    (   .clk(clk), .ena(!stall && _hot_ISR),
//        .addra(DMEM_ADDR[15:2]),  //input [13:0]
//        .wea(_WriteMask),  .dina(_WDataMasked),
//        .addrb(IMEM_ADDR[15:2]),  //input [13:0]
//        .doutb(INST_ISR)
//    );
    isr_mem bram_isr
    ( .clka(clk), .ena(!stall && _hot_ISR),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_ISR),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
    // INSTRUCTION Fletch (sic :)
        .clkb(clk),   .addrb(IMEM_ADDR[13:2]),
        .enb(1'b1),   .web(4'b0000),
        .dinb(32'd0), .doutb(INST_ISR) //No use for hoti_ISR_
    ) /* synthesis syn_noprune=1 */;


    wire Rx_Ready, Rx_Valid, Tx_Valid, Tx_Ready;
    wire [7:0] Rx_Data, Tx_Data;
    MemMapIO memmap
    (   .clk(clk), .rst(rst), .stall(stall),
        .ena(!stall && _hot_IO), //NOTE: Manage "ena" like a memory
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
    //UART
        .Rx_Ready(Rx_Ready),   // OUT: We offer to take a byte
        .Rx_Valid(Rx_Valid),   // IN : UART announcing a byte
        .Rx_Data(Rx_Data),     // IN : Data from UART
        .Tx_Data(Tx_Data),     // OUT: Data to UART
        .Tx_Valid(Tx_Valid),   // OUT: We announce a byte
        .Tx_Ready(Tx_Ready),   // IN : UART can take a byte from us
    //GPU control
                                .gp_rcode(gp_rcode),
        .pf_status(pf_status),                       .gp_status(gp_status),
        .pf_vframe(pf_vframe),  .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),  .gp_wcode(gp_wcode), .gp_wframe(gp_wframe)
    ) /* synthesis syn_noprune=1 */;

    UART #(
        .CLOCK_FREQ(CPU_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_mem (
        .Clock(clk),  .Reset(rst),
        .SInRX(SerialRX),  .SOutTX(SerialTX),  //Serial in & out
        .DataOutReadyRX(Rx_Ready),  //IN
        .DataOutValidRX(Rx_Valid),  //OUT
        .DataOutRX(Rx_Data),        //OUT
        .DataInTX(Tx_Data),         //IN
        .DataInValidTX(Tx_Valid),   //IN
        .DataInReadyTX(Tx_Ready)    //OUT
    ) /* synthesis syn_noprune=1 */;

    // Prior clock state for "edge" -> "pulse" conversion
    reg WAS_Rx_Valid, WAS_Tx_Ready;
    always @(posedge clk) begin:_REG_WAS_
        //NOTE:Avoid unnecessary resets --if (Reset) {WAS_Rx_Valid,WAS_Tx_Ready} <= 0; else
        {WAS_Rx_Valid,WAS_Tx_Ready} <= {Rx_Valid,Tx_Ready};
    end
    assign irq_uart0 = (Rx_Valid && !WAS_Rx_Valid);
    assign irq_uart1 = (Tx_Ready && !WAS_Tx_Ready);


//=============DEBUGGING TOOLS BELOW THIS POINT=============
`ifndef COLT45_KILLFUN //Mostly to trigger text editor to hide this whole mess!

// SIMULATION ONLY business

// synthesis translate_off

generate if (COLT45_MEMWRITE) begin:_MEMWRITE_
    always@(posedge clk) if (!stall && |_WriteMask) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        $display("** [%h,%d] <= %h(%d) {%b}",
            DMEM_ADDR, DMEM_ADDR, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            DMEM_ADDR[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
    end
end endgenerate

generate if (COLT45_SCRATCH) begin:_SCRATCH_
    always@(posedge clk) if (!stall && _hot_DB) begin
        $display("\n=============");
        DUMP_PC();
        $display("TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            DMEM_ADDR[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
        if (|_WriteMask) begin
            regfile.DUMP();
            $display("[%h,%d] <<= %h(%d) {%b}",
                DMEM_ADDR, DMEM_ADDR, _WDataMasked, _WDataMasked, _WriteMask);
        end else begin
            $display("[%h,%d] ==> %h(%d)",
                DMEM_ADDR, DMEM_ADDR, RData_DB, RData_DB);
        end
        $display("=============\n");
    end
end endgenerate

// synthesis translate_on

`else //COLT45_KILLFUN (either def/ndef check)


`endif //COLT45_KILLFUN (either def/ndef check)

endmodule
