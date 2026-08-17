`timescale 1ns/1ps

`include "../cpuglobal.vh"
`include "../tuntap.vh"

module MemBank #(
    parameter CPU_FREQ = 50_000_000,
    parameter [31:0] DEAD_DMEM = 32'd0, DEAD_IMEM = 32'd0,
    parameter BRAM_XTRA = 0, //Scratchpad EXTRA block-rams
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

// Interrupts:
    output irq_UARX, irq_UATX,

// Serial (UART):
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,

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

//TODO: Why is hoti_XYZ_ unlike _hot_XYZ???

    reg hoti_ISR_, hoti_BR_, hoti_IC_;
    reg hoti_X6_, hoti_X5_; //TODO: Conditional on BRAM_XTRA parameter?
    always @(*) begin:_MUX_HOTI_ //Drive appropriate "activate" line for INSTRUCTION fetch
        {hoti_ISR_, hoti_BR_, hoti_IC_} = 0;
        {hoti_X6_, hoti_X5_} = 0; //TODO: Conditional?
        case (IMEM_ADDR[31:28])
            4'b1100: hoti_ISR_ = 1'b1;      //0xC => ISR
            // No hoti_IO_ can't execute IO!  0x8 IO map
            4'b0110: hoti_X6_ = BRAM_XTRA;  //0x6 => X6 (WAS IMEM)
            4'b0101: hoti_X5_ = BRAM_XTRA;  //0x5 => X5 (WAS DMEM)
            4'b0100: hoti_BR_ = 1'b1;       //0x4 => BR
            4'b0011: hoti_IC_ = 1'b1;       //0x3 => IC
            4'b0010: hoti_IC_ = 1'b1;       //0x2 => IC
            4'b0001: hoti_IC_ = 1'b1;       //0x1 => IC
        endcase
    end

    reg _hot_ISR, _hot_IO, _hot_BR, _hot_IC, _hot_DC;
    reg _hot_X6, _hot_X5; //TODO: Conditional on BRAM_XTRA parameter?
    always @(*) begin
        //NOTE: Ensure case assignments have a default value
        {_hot_ISR, _hot_IO, _hot_BR, _hot_IC, _hot_DC} = 0;
        {_hot_X6, _hot_X5} = 0; //TODO: Conditional?
        if (MemToRegDX_ || MemWriteDX_) begin
            case (DMEM_ADDR[31:28]) //TODO: Just use hexadecimal nibble, not binary!
                4'b1100: _hot_ISR = 1'b1;                      //ISR  0xC
                4'b1000: _hot_IO = 1'b1;                       //IO   0x8
                4'b0110: _hot_X6 = BRAM_XTRA && 1'b1;          //X6   0x6 WAS IMEM
                4'b0101: _hot_X5 = BRAM_XTRA && 1'b1;          //X5   0x5 WAS DMEM
                4'b0100: _hot_BR = !MemWriteDX_;               //BIOS 0x4 Read-Only
                4'b0011: begin                                 //DDR  0x3 Both I & D
                        _hot_IC = MemWriteDX_ && PCinBIOSDX_;  // INST CACHE from BIOS
                        _hot_DC = 1'b1;                        // DATA CACHE
                    end                                        // 
                4'b0010: _hot_IC = MemWriteDX_ && PCinBIOSDX_; //INST 0x2
                4'b0001: _hot_DC = 1'b1;                       //DATA 0x1
            endcase
        end
    end


    reg         P_dcache_re;
    reg  [31:0] P_dcache_addr;
    reg  [ 3:0] P_selI, P_selD;
    always @(posedge clk) begin:_REG_PRIOR_
        P_dcache_re <= dcache_re;
        P_dcache_addr <= dcache_addr;
        if (!stall) begin  //High nibble identifies which memory
            P_selI <= IMEM_ADDR[31:28];
            P_selD <= DMEM_ADDR[31:28];
        end
    end


    wire [31: 0] RINST_ISR, RINST_BR, RINST_IC;
    wire [31: 0] RINST_X6, RINST_X5;
    reg  [31: 0] MUX_IMEM;
    always @(*) begin:_MUX_IMEM_ //Drive instruction from appropriate memory component
        case (P_selI)
            4'b1100: MUX_IMEM = RINST_ISR;                      // 0xC ISR
            4'b1000: MUX_IMEM = DEAD_IMEM;                      // 0x8 Can't execute IO!
            4'b0110: MUX_IMEM = (BRAM_XTRA)?RINST_X6:DEAD_IMEM; // 0x6 X6
            4'b0101: MUX_IMEM = (BRAM_XTRA)?RINST_X5:DEAD_IMEM; // 0x5 X5
            4'b0100: MUX_IMEM = RINST_BR;                       // 0x4 BIOS
            4'b0011: MUX_IMEM = RINST_IC;                       // 0x3 INST-only
            4'b0010: MUX_IMEM = RINST_IC;                       // 0x2 INST
            4'b0001: MUX_IMEM = RINST_IC;                       // 0x1 Use INST
            default: MUX_IMEM = DEAD_IMEM;
        endcase
    end
    assign IMEM_DATA = MUX_IMEM;


    wire [31: 0] RDATA_ISR, RDATA_IO, RDATA_BR, RDATA_DC;
    wire [31: 0] RDATA_X6, RDATA_X5;
    reg  [31: 0] MUX_DMEM;
    always @(*) begin:_MUX_DMEM_
        case (P_selD)
            4'b1100: MUX_DMEM = RDATA_ISR;                      // 0xC ISR
            4'b1000: MUX_DMEM = RDATA_IO;                       // 0x8 IO
            4'b0110: MUX_DMEM = (BRAM_XTRA)?RDATA_X6:DEAD_DMEM; // 0x6 XTRA X6
            4'b0101: MUX_DMEM = (BRAM_XTRA)?RDATA_X5:DEAD_DMEM; // 0x5 XTRA X5
            4'b0100: MUX_DMEM = RDATA_BR;                       // 0x4 BIOS
            4'b0011: MUX_DMEM = RDATA_DC;                       // 0x3 DATA-only
            4'b0010: MUX_DMEM = RDATA_DC;                       // 0x2 Use DATA
            4'b0001: MUX_DMEM = RDATA_DC;                       // 0x1 DATA
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
        RDATA_DC    = dcache_dout;
//    assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0, RDATA_DC=32'd0;

    //NOTE: Both _hot_DC && _hot_IC ARE allowed to be active simultaneously for WRITE
    //      but writability rules prevent INST-read & DATA-write collision
    assign icache_addr = {4'h0, (hoti_IC_) ? IMEM_ADDR[27:0] : DMEM_ADDR[27:0]},
        icache_we   = (!stall && !hoti_IC_ && _hot_IC) ? (_WriteMask) : 4'b0000,
        icache_din  = _WDataMasked,
        icache_re   = (!stall && hoti_IC_),
        RINST_IC     = icache_dout;
//    assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0, RINST_IC=32'd0;

    // BIOS is read-only "ROM"
    bios_mem bram_bios
    ( .clka(clk), .ena(!stall && _hot_BR),
        .addra(DMEM_ADDR[13:2]),
        .douta(RDATA_BR),//OUT-32

    // Instruction reading port (b)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_BR_), .doutb(RINST_BR)
    ) /* synthesis syn_noprune=1 */;

    // Using "True Dual Port RAM"
    isr_mem bram_isr
    ( .clka(clk), .ena(!stall && _hot_ISR),
        .addra(DMEM_ADDR[13:2]),
        .douta(RDATA_ISR),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fetch
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_ISR_), .doutb(RINST_ISR),
        .web(4'b0000), .dinb(32'h0)
    ) /* synthesis syn_noprune=1 */;

    // Using "True Dual Port RAM"
    dmem_blk_ram bram_dmem
    ( .clka(clk), .ena(!stall && _hot_X5),
        .addra(DMEM_ADDR[13:2]),
        .douta(RDATA_X5),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fetch
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_X5_), .doutb(RINST_X5),
        .web(4'b0000), .dinb(32'h0)
    ) /* synthesis syn_noprune=1 */;

    // Using "True Dual Port RAM"
    imem_blk_ram bram_imem
    ( .clka(clk), .ena(!stall && _hot_X6),
        .addra(DMEM_ADDR[13:2]),
        .douta(RDATA_X6),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fetch
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_X6_), .doutb(RINST_X6),
        .web(4'b0000), .dinb(32'h0)
    ) /* synthesis syn_noprune=1 */;

    `BUS_RVA_type(8) UATX, UARX; //UART is RVA SHAKE. Could easily go to FIFO, FSL, etc. for fun!
    MemMapIO memmap
    ( .clk(clk), .rst(rst), .stall(stall),
        .ena(!stall && _hot_IO), //NOTE: Manage "ena" like a memory
        .addra(DMEM_ADDR[13:2]),
        .douta(RDATA_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
    //RVAs
        .RVa_RX(UARX), .RVa_TX(UATX),
    //GPU control
                                .gp_rcode(gp_rcode),
        .pf_status(pf_status),                       .gp_status(gp_status),
        .pf_vframe(pf_vframe),  .gp_vcode(gp_vcode), .gp_vframe(gp_vframe),
        .pf_wframe(pf_wframe),  .gp_wcode(gp_wcode), .gp_wframe(gp_wframe)
    ) /* synthesis syn_noprune=1 */;

    UARTRVA #(.ClockFreq(CPU_FREQ)) uartrva
    ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX),  .UARX(UARX),   .IRQ_RX(irq_UARX), //Receiver
        .UATX(UATX),  .SOut(FPGA_SERIAL_TX),  .IRQ_TX(irq_UATX) //Transmitter
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
        $display("** TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b X6=%b X5=%b",
            DMEM_ADDR[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_X6, _hot_X5);
    end
end endgenerate

generate if (COLT45_SCRATCH) begin:_SCRATCH_
    always@(posedge clk) if (!stall && _hot_X5) begin
        $display("\n=============");
        DUMP_PC();
        $display("TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b X6=%b X5=%b",
            DMEM_ADDR[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_X6, _hot_X5);
        if (|_WriteMask) begin
            regfile.DUMP();
            $display("[%h,%d] <<= %h(%d) {%b}",
                DMEM_ADDR, DMEM_ADDR, _WDataMasked, _WDataMasked, _WriteMask);
        end else begin
            $display("[%h,%d] ==> %h(%d)",
                DMEM_ADDR, DMEM_ADDR, RDATA_X5, RDATA_X5);
        end
        $display("=============\n");
    end
end endgenerate

// synthesis translate_on

`else //COLT45_KILLFUN (either def/ndef check)


`endif //COLT45_KILLFUN (either def/ndef check)

endmodule
