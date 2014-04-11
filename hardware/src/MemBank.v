`include "cpuglobal.vh"

module MemBank #(
    parameter CPU_FREQ = 50_000_000,
    parameter [31:0] DEAD_DMEM = 32'd0, DEAD_IMEM = 32'd0,
    parameter XTRA_IMEM = 0, XTRA_DMEM = 0, //Scratchpad extra block-rams
    parameter DD=`COLT45_DD,
    parameter COLT45_SCRATCH=0, COLT45_MEMWRITE=0
)(
    input   clk,
    input   rst,
    input   stall,

// Memory/IO lines (snagged from MIPS150):
    input  [31: 0]  IMEM_ADDR, DMEM_ADDR,
    output [31: 0]  IMEM_DATA, DMEM_DATA,
    input           MemToRegDX_, MemWriteDX_, PCinBIOSDX_, //TODO:Rename
    input  [31: 0]  _WDataMasked, //TODO:Rename
    input  [ 3: 0]  _WriteMask,
    input  [31: 0]  CNT_Cycle, CNT_Inst, //TODO:Move?
    output          CNT_Reset_MW2F_,

// Interrupts:
    output uart0_irq, uart1_irq,

// Serial (UART):
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,

// Memory Caches:
    output [ 31:0]  dcache_addr,
    output [ 31:0]  icache_addr,
    output [  3:0]  dcache_we,
    output [  3:0]  icache_we,
    output          dcache_re,
    output          icache_re,
    output [ 31:0]  dcache_din,
    output [ 31:0]  icache_din,
    input  [ 31:0]  dcache_dout,
    input  [ 31:0]  icache_dout,

// Graphics:
    input  [ 31:0]  graphics_status,
    output          pf_valid,
    output [ 31:0]  pf_frame,
    output          gp_valid,
    output [ 31:0]  gp_frame,
    output [ 31:0]  gp_code
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
    always @(*) begin
        {_hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR} = 0;
        if (MemToRegDX_ || MemWriteDX_) begin
            case (DMEM_ADDR[31:28])
                4'b1000: _hot_IO = 1'b1;                        //  0x8
                4'b0100: _hot_BR = !MemWriteDX_;        //Read-only 0x4
                4'b0011: begin                                  //  0x3
                        _hot_DC = 1'b1;
                        _hot_IC = MemWriteDX_ && PCinBIOSDX_;
                    end
                4'b0010: _hot_IC = MemWriteDX_ && PCinBIOSDX_;  //  0x2
                4'b0001: _hot_DC = 1'b1;                        //  0x1
                4'b0110: _hot_IB = XTRA_IMEM && MemWriteDX_; //XTRA:Scratch-IMEM 0x6
                4'b0101: _hot_DB = XTRA_IMEM && 1'b1;        //XTRA:Scratch-DMEM 0x5
                4'b1100: _hot_ISR = MemWriteDX_; //ISR//
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
            4'b1000: MUX_IMEM = INST_ISR;       //0xC => ISR
            4'b0100: MUX_IMEM = INST_BR;        //0x4 => BR
            4'b0010: MUX_IMEM = INST_IC;        //0x1 => IC
            4'b0001: MUX_IMEM = (XTRA_IMEM)?INST_IB:DEAD_IMEM;//XTRA:  0x6 => IB (Scratch-IMEM)
            default: MUX_IMEM = DEAD_IMEM; //TODO: Make "HALT" instruction rather than "NOP"
        endcase
    end
    assign IMEM_DATA = MUX_IMEM;


    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB;
    reg  [31: 0] MUX_DMEM;
    always @(*) begin:_MUX_DMEM_
        case (P_selD)
            4'b1000: MUX_DMEM = RData_IO;                       //  0x8
            4'b0100: MUX_DMEM = RData_BR;                       //  0x4
            4'b0011: MUX_DMEM = RData_DC;                       //  0x3
            4'b0001: MUX_DMEM = RData_DC;                       //  0x1
            4'b0101: MUX_DMEM = (XTRA_DMEM)?RData_DB:DEAD_DMEM;//XTRA: Scratchpad-DMEM  0x5
            default: MUX_DMEM = DEAD_DMEM;
        endcase // CAUTIOUS trapping of EVERY case
    end
    assign DMEM_DATA = MUX_DMEM;


    // MEMORY/MMIO ELEMENTS (straddle MW & F stages & interface outside CPU)

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

    isr_mem bram_isr
    ( .clka(clk), .ena(!stall && _hot_ISR),
        .addra(DMEM_ADDR[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_ISR) //No use for hoti_ISR_
    ) /* synthesis syn_noprune=1 */;

    bios_mem brom_bios
    ( .clka(clk), .ena(!stall && _hot_BR),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/

    // Instruction reading port (b)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_BR_), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

    dmem_blk_ram bram_dmem
    ( .clka(clk), .ena(!stall && _hot_DB),
        .addra(DMEM_ADDR[13:2]),
        .douta(RData_DB),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked)
    ) /* synthesis syn_noprune=1 */;

    imem_blk_ram bram_imem
    ( .clka(clk), .ena(!stall && _hot_IB),
        .addra(DMEM_ADDR[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB) //No use for hoti_IB_
    ) /* synthesis syn_noprune=1 */;

    `BUS_SHAKE_type(8) UATX, UARX; //UART is RVA SHAKE. Could easily go to FIFO, FSL, etc. for fun!
    MemMapIO memmap_io
    ( .clk(clk), .rst(rst), .ena(!stall && _hot_IO), //NOTE: Manage "ena" like a memory
        .addra(DMEM_ADDR[13:2]),
        .DOUTA(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
        //Mapped RVA devices
        .RVa_RX(UARX),          .RVa_TX(UATX),
        .RVa_RX_IRQ(uart0_irq), .RVa_TX_IRQ(uart1_irq),
        //Counters
        .CNT_Cycle(CNT_Cycle), .CNT_Inst(CNT_Inst),
        .CNT_RESET_(CNT_Reset_MW2F_),
        //PixelFeeder & GraphicsController
        .graphics_status(graphics_status),
        .PF_VALID(pf_valid), .PF_FRAME(pf_frame),
        .GP_VALID(gp_valid), .GP_FRAME(gp_frame), .GP_CODE(gp_code)
    ) /* synthesis syn_noprune=1 */;

    UARTRVA #(.ClockFreq(CPU_FREQ)) uartrva
    ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .UARX(UARX), //Receiver
        .UATX(UATX), .SOut(FPGA_SERIAL_TX) //Transmitter
    ) /* synthesis syn_noprune=1 */;


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
