`include "cpuglobal.vh"

module MIPS150 #(
    parameter DD=`COLT45_DD,
    parameter ClockFreq=50_000_000,
    parameter COLT45_BRK=0, COLT45_SCOPE=1,
    parameter COLT45_SCRATCH=0, COLT45_PC=0,
    parameter COLT45_REGREAD=0, COLT45_MEMWRITE=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
)(
    input clk,
    input rst,

    // Serial
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

// CP2+
    // Memory system connections
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output [3:0] icache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    output [31:0] icache_din,
    input [31:0] dcache_dout,
    input [31:0] icache_dout,
    input stall,

// CP4+
    output [31:0] gp_code,
    output [31:0] gp_frame,
    output gp_valid,
    input frame_interrupt
);

// CP4+
    assign gp_code=32'd0, gp_frame=32'd0;
    assign gp_valid = 1'b0;

//BRK tap (in transition)
    wire [0:1023] trace;
    wire brk = 1'b0;

//TODO: Ensure naming convention consistency (and/or simplify convention)

/*
  NAMING CONVENTIONS: (might be inconsistent/in-flux though :)
    SUFFIX for stage code (F, DX, MW) == (instFetch, Decode-Execute, Memory-WriteBack)
    xxxSS_  : Value unstable during given stage (but stable at posedge exit)
    Typical output of a stage/module (headed to next stage somehow).
    xxx_SS  : Value stable during entire given stage (explicitly registered by pipeline).
    Output of a prior stage after being registered by pipeline reg,
    used as input to a given stage.
    xxx_SS_ : As with SS_ except is already REGISTER'd at exit of output stage.
    OUTPUT is FROM an internal component that is unavoidably synchronous.
    xxx__SS : Redundant with xxxSS_ except is named relative to the inbound stage.
    From this point of view, a stage is peering into it's prior stage's
    value, getting a preview of the value before the clock strikes.
    INPUT is TO an internal component that is unavoidably synchronous.

    Internal to a stage (and sometimes for input/output interface):
    _xxx    : Value is "hot" from prior stage (unregistered/passthrough/preview).
    xxx     : Value was registered prior (either by prior stage or by pipeline reg).
    ....

  DATA PATH:
    Top-to-bottom in this file depicts general "forward-flow" of datapath through
        3 stages with clock edge.  Implied "wraparound" bottom-backto-top matches
        notion of overlapped stages in a instruction vs. clock/stage pipeline diagram.
    Modules are less embedded to avoid excessive signal passing when they straddle
        stages or contribute debug taps (temporary or permanent).
    Though design is "flattened", modules are placed between pipeline divisions
        or near their most related stage where possible (REGFILE&COP0, MEM/MEMIO).
        (Memory placement complicated by separate inst/data but helped by "wraparound")
    Signals tend to be decleared ALAP to communicate general "forward" datapath.
    Appropriate "violations" named to depict purpose (feedback/forwarding, async taps),
        with redundant "local" signal assigned for clarity.
*/


    // Forward declare feedback related wires (other key wires declared just prior to use, ALAP)
    wire         #DD BRA_DoBranch_DX2F_;
    wire [31: 0] #DD BRA_PCBranch_DX2F_;
    wire [ 4: 0] #DD WBK_Reg_MW2DX_;
    wire [31: 0] #DD WBK_Val_MW2DX_;
    wire         #DD WBK_CanFWD_MW2DX_;
    wire         #DD CNT_Reset_MW2F_;

    // Declare outputs of F stage
    wire [31: 0] PC_F_;
    wire [31: 0] INST_F_;
    wire [63: 0] CNT_Cycle, CNT_Inst, CNT_Stall;
    wire WAS_Stall, WAS_Inst;
    wire [31: 0] IMEM_ADDR;
    wire [31: 0] IMEM_DATA;
    StageF #(
        .BOOTPC(32'h4000_0000), //NOTE: h6000_0000 for SCRATCH_IMEM
        .COUNTERWIDTH(64)
    ) s_F ( .clk(clk), .rst(rst), .stall(stall),
        //Inputs (feedback from other stages)
        ._DoBranch(BRA_DoBranch_DX2F_), ._PCBranch(BRA_PCBranch_DX2F_),
        ._ResetCounters(CNT_Reset_MW2F_),
        //Outputs (toward next stage)
        .PC_(PC_F_), .INST_(INST_F_),
        //CPU Counters & Prior-state flags
        .CNT_CYCLE(CNT_Cycle), .CNT_INST(CNT_Inst), .CNT_STALL(CNT_Stall),
        .WAS_STALL(WAS_Stall), .WAS_INST(WAS_Inst),
        //Instruction memory taps
        .IMEM_ADDR(IMEM_ADDR), .IMEM_Data(IMEM_DATA)
    );


//=============--- "PIPELINE"-PEEK: F/DX ---=============
    wire [31: 0] PC_DX, INST_DX;
    PipelineRegister #( .Width(32) )
        PIPR_PC_DX    ( .clk(clk), .rst(rst), .stall(stall),
                        .In(PC_F_),     .Out(PC_DX) );
    PipelineRegister #( .Width(32) )
        PIPR_INST_DX  ( .clk(clk), .rst(rst), .stall(stall),
                        .In(INST_F_),   .Out(INST_DX) );
//=============<<< PIPELINE-BORDER: F/DX |===============

    // REGFILE async-read via DX-stage but sync-write via M-stage WB
    wire [ 4: 0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
    wire [31: 0] REGFILE_rd1, REGFILE_rd2, REGFILE_wd;
    assign REGFILE_wa = WBK_Reg_MW2DX_, REGFILE_wd = WBK_Val_MW2DX_;
    wire REGFILE_we = !stall && (REGFILE_wa != 0); // Mute "we" if "wa"==0 for signal clarity
    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .we(REGFILE_we), .wa(REGFILE_wa), .wd(REGFILE_wd),
        // Read is asynchronous & always enabled (even during stall...MUST hold ra1/2 steady)
        .ra1(REGFILE_ra1), .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2), .rd2(REGFILE_rd2)
    );
    // FORWARDING calculation (a "virtual" behavior tacked onto REGFILE)
    wire FWD_Allow = WBK_CanFWD_MW2DX_; // Has already checked for "wa"==0 elsewhere
    wire FWD_1 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra1) : 1'b0;
    wire FWD_2 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra2) : 1'b0;
    wire [31: 0] #DD FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] #DD FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // COPROCESSOR async-read via DX-stage (like REGFILE) but sync-write from REGFORWARD
    wire [ 4: 0] CopAddr;
    wire [31: 0] CopOut;
    wire CopInHot, IRQUART0, IRQUART1, IRQPending;
    COP0150 cop0 (
        .Clock(clk), .Reset(rst), .Enable(1'b0), //TODO: ENABLE! Disable until handled?
        .DataAddress(CopAddr), //IN-5 (Cop Register to read/write)
        .DataOut(CopOut), //OUT-32 (Injected into StageDX.RegWValue_)
        .DataInEnable(CopInHot), //IN (mtc0)
        .DataIn(FWD_rd2), //IN-32 (Always fed, only used if enabled)
        .InterruptedPC(PC_DX), //IN-32 (PC_DX or similar)
        .InterruptHandled(1'b0), //IN (Acknowledge the branch is happening)
        .InterruptRequest(IRQPending), //OUT (Like a branch to fixed address)
        .UART0Request(IRQUART0), .UART1Request(IRQUART1) //IN (edge detect "pulse")
    );
    //TODO: Pick correct PC to stash at right time (utilize branch)

    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] MemAddrDX_, MemWValueDX_, RegWValueDX_;
    StageDX s_DX
    ( //NOTE: Currently async: .clk(clk), .rst(rst), .stall(stall),
        //Async regfile reads & COP access
        .REG_R1_(REGFILE_ra1), .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2), .REG_D2_(FWD_rd2),
        .CopAddr(CopAddr), .CopOut(CopOut), .CopInHot(CopInHot),
        //Stage Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Stage Outputs
        .IControl_(IControlDX_),
        .MemAddr_(MemAddrDX_), .MemWValue_(MemWValueDX_),
        .RegWValue_(RegWValueDX_),
        //Feedback outputs
        .DOBranch_(BRA_DoBranch_DX2F_), .PCBranch_(BRA_PCBranch_DX2F_)
    );


//=============--- "PIPELINE"-PEEK: DX/M ---=============
    `BUS_ICTL_type  IControl__MW = IControlDX_;
    wire  [31: 0]   MemAddr__MW = MemAddrDX_;
    wire  [31: 0]   MemWValue__MW = MemWValueDX_;
//===============| PIPELINE-BORDER: DX/M >>>=============
    `BUS_ICTL_type IControl_MW;
    wire  [31: 0]   MemAddr_MW;
    wire  [31: 0]   RegWValue_MW;
    PipelineRegister #( .Width(`BUS_ICTL_width) )
        PIPR_IControl_MW  ( .clk(clk), .rst(rst), .stall(stall),
                            .In(IControlDX_),   .Out(IControl_MW  ) );
    PipelineRegister #( .Width(32) )
        PIPR_MemAddr_MW   ( .clk(clk), .rst(rst), .stall(stall),
                            .In(MemAddrDX_  ),  .Out(MemAddr_MW   ) );
    PipelineRegister #( .Width(32) )
        PIPR_RegWValue_MW ( .clk(clk), .rst(rst), .stall(stall),
                            .In(RegWValueDX_),  .Out(RegWValue_MW ) );
//Debug use only
    wire  [31: 0]   PC_MW;
    PipelineRegister #( .Width(32) ) //NOTE: Only need 1 bit, but full value nice for debugging
        PIPR_PC_MW        ( .clk(clk), .rst(rst), .stall(stall),
                            .In(PC_DX       ),  .Out(PC_MW        ) );
//=============<<< PIPELINE-BORDER: DX/M |===============

    // MEMORY/MMIO patchwork lines ("setups" prefixed with "_", "results" not)
    wire _hot_ISR, _hot_IO, _hot_BR, _hot_IC, _hot_DC;
    wire _hot_IB, _hot_DB;
    wire [ 3: 0] _WriteMask, _ByteMask;
    wire [31: 0] _WDataMasked;
    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB;
    StageMW s_MW
    ( //NOTE: Currently async: .clk(clk), .rst(rst), .stall(stall),
        //Inputs
        ._IControl  (IControl__MW),  .IControl   (IControl_MW),
        ._MemAddr   (MemAddr__MW),   .MemAddr    (MemAddr_MW),
        ._MemWValue (MemWValue__MW), .RegWValue  (RegWValue_MW),
        ._PCinBIOS  (PC_DX[31:28]==4'b0100), //Borrow value from other stage (close enough)
        //Feedbacks to "prior" stages (forwarding & instruction fetch)
        .WBK_Reg_(WBK_Reg_MW2DX_), .WBK_Val_(WBK_Val_MW2DX_),
        .WBK_CanFWD_(WBK_CanFWD_MW2DX_),
        //Memory/MMIO "pre-clock" drives OUT
        ._hot_IO(_hot_IO), ._hot_BR(_hot_BR), ._hot_DC(_hot_DC),
        ._hot_IB(_hot_IB), ._hot_DB(_hot_DB), //XTRA: Scratchpad
        ._hot_IC(_hot_IC), ._hot_ISR(_hot_ISR), //Write-only via I-Cache (keep fetch consistent later)
        ._WriteMask(_WriteMask), ._WDataMasked(_WDataMasked), ._ByteMask(_ByteMask),
        //Memory/MMIO "post-clock" results IN
        .RData_IO(RData_IO), .RData_BR(RData_BR), .RData_DC(RData_DC),
        .RData_DB(RData_DB)
    );


    reg [3:0] hoti_;
    always @(*) begin:_MUX_HOTI_ //Drive appropriate "activate" line for instruction fetch
        case (IMEM_ADDR[31:28])
            4'b1100: hoti_ = 4'b1000; //0xC => ISR
            4'b0100: hoti_ = 4'b0100; //0x4 => BR
            4'b0001: hoti_ = 4'b0010; //0x1 => IC
`ifndef COLT45_STRICT
            4'b0110: hoti_ = 4'b0001; //XTRA: Scratchpad-IMEM: 0x6 => IB
`endif
            default: hoti_ = 4'b0000;
        endcase
    end

    wire hoti_BR_  = hoti_[2];
    wire hoti_IC_  = hoti_[1];

    wire [ 3: 0] _hoti;
    PipelineRegister #( .Width(4) )
        PIPR_HOTI ( .clk(clk), .rst(rst), .stall(stall),
                    .In(hoti_), .Out(_hoti) );

    wire [31: 0] INST_ISR, INST_BR, INST_IC, INST_IB;
    reg  [31: 0] MUX_IMEM;
    always @(*) begin:_MUX_IMEM_ //Drive instruction from appropriate memory component
        case (_hoti)
            4'b1000: MUX_IMEM = INST_ISR; //0xC => ISR
            4'b0100: MUX_IMEM = INST_BR; //0x4 => BR
            4'b0010: MUX_IMEM = INST_IC; //0x1 => IC
`ifndef COLT45_STRICT
            4'b0001: MUX_IMEM = INST_IB; //XTRA: Scratchpad-IMEM: 0x6 => IB
`endif
            default: MUX_IMEM = 0; //NOP
        endcase
    end
    assign IMEM_DATA = MUX_IMEM;


    // MEMORY/MMIO ELEMENTS (straddle MW & F stages & interface outside CPU)

    //NOTE: DRAM rollsover at 0x0200_0000 but not imposing limit in CPU (just top nibble)
    assign dcache_addr = {4'h0, MemAddr__MW[27:0]},
        dcache_we   = (!stall && _hot_DC) ? (_WriteMask) : 4'b0000,
        dcache_din  = _WDataMasked,
        dcache_re   = (!stall && _hot_DC) && !(|_WriteMask),
        RData_DC    = dcache_dout;
//    assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0, RData_DC=32'd0;

    //NOTE: Both _hot_DC && _hot_IC ARE allowed to be active simultaneously for WRITE
    //      but writability rules prevent INST-read & DATA-write collision
    assign icache_addr = {4'h0, (_hot_IC) ? MemAddr__MW[27:0] : IMEM_ADDR[27:0]},
        icache_we   = (!stall && _hot_IC) ? (_WriteMask) : 4'b0000,
        icache_din  = _WDataMasked,
        icache_re   = (!stall && hoti_IC_ && !_hot_IC),
        INST_IC     = icache_dout;
//    assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0, INST_IC =32'd0;

    isr_mem bram_isr
    ( .clka(clk), .ena(!stall && _hot_ISR),
        .addra(MemAddr__MW[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_ISR) //No use for hoti_ISR_
    ) /* synthesis syn_noprune=1 */;

    bios_mem brom_bios
    ( .clka(clk), .ena(!stall && _hot_BR),
        .addra(MemAddr__MW[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/

    // Instruction reading port (b)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
        .enb(hoti_BR_), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

    dmem_blk_ram bram_dmem
    ( .clka(clk), .ena(!stall && _hot_DB),
        .addra(MemAddr__MW[13:2]),
        .douta(RData_DB),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked)
    ) /* synthesis syn_noprune=1 */;

    imem_blk_ram bram_imem
    ( .clka(clk), .ena(!stall && _hot_IB),
        .addra(MemAddr__MW[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(IMEM_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB) //No use for hoti_IB_
    ) /* synthesis syn_noprune=1 */;

    `BUS_SHAKE_type(8) UATX, UARX; //UART is RVA SHAKE. Could easily go to FIFO, FSL, etc. for fun!
    MemMapIO memmap_io
    ( .clk(clk), .rst(rst), .ena(!stall && _hot_IO), //NOTE: Manage "ena" like a memory
        .addra(MemAddr__MW[13:2]),
        .DOUTA(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
        //Mapped devices
        .RVa_RX(UARX),          .RVa_TX(UATX),
        .RVa_RX_IRQ(IRQUART0),  .RVa_TX_IRQ(IRQUART1),
        //Counters
        .CNT_Cycle(CNT_Cycle[31:0]), .CNT_Inst(CNT_Inst[31:0]),
        .CNT_RESET_(CNT_Reset_MW2F_)
    ) /* synthesis syn_noprune=1 */;

    UARTRVA #(.ClockFreq(ClockFreq)) uartrva
    ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .UARX(UARX), //Receiver
        .UATX(UATX), .SOut(FPGA_SERIAL_TX) //Transmitter
    ) /* synthesis syn_noprune=1 */;


//=============DEBUGGING TOOLS BELOW THIS POINT=============
`ifndef COLT45_KILLFUN //Mostly to trigger text editor to hide this whole mess!

//Shared between BRK and SCOPE

wire [31:0] keywatch = {
    REGFILE_we,FWD_Allow,FWD_1,FWD_2, REGFILE_wa[3:0],
    REGFILE_ra1[3:0], REGFILE_ra2[3:0],
    _hot_IO,_hot_BR,_hot_IC,_hot_DC,
        _hot_ISR,_hot_IB,_hot_DB,PC_MW[30],
    hoti_[3:0], rst,IRQPending,BRA_DoBranch_DX2F_,stall
};

assign trace = {
// 3 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
    // 0 \\             // 1 \\             // 2 \\             // 3 \\
    PC_DX[31:0],        INST_DX[31:0],      CNT_Inst[31:0],     BRA_PCBranch_DX2F_[31:0],
    FWD_rd1[31:0],      FWD_rd2[31:0],      REGFILE_wd[31:0],   keywatch[31:0],

//  DMEM_READ[31:0],    32'd0,              32'd0,              32'd0,
    RData_IO[31:0],     RData_BR[31:0],     RData_DC[31:0],     RData_DB[31:0],
    MemAddr_MW[31:0],   MemAddr__MW[31:0],  _WDataMasked[31:0],
    {8'd0, 8'd0, 8'd0, _WriteMask,_ByteMask},

    IMEM_ADDR[31:0],    IMEM_DATA[31:0],    CNT_Stall[31:0],    PC_MW[31:0],
    {41'd0,IControlDX_[22:0]},              {41'd0,IControl_MW[22:0]},

    PC_F_[31:0],        INST_F_[31:0],      CNT_Cycle[63:0],
    CNT_Inst[63:0],                         CNT_Stall[63:0]
};


generate if (COLT45_BRK) begin:_BRK_
    //TODO: Move from top to here
end endgenerate //COLT45_BRK


generate if (COLT45_SCOPE) begin:_SCOPE_
    wire [31:0] CS_TRIG0 = keywatch[31:0];
    wire [31:0] CS_TRIG1 = PC_DX[31:0];
    wire [31:0] CS_TRIG2 = INST_DX[31:0];
    wire [31:0] CS_TRIG3 = CNT_Inst[31:0];

    wire [35: 0] cs_icon_scope;
    cs_icon_1 CS_ICON (
        .CONTROL0(cs_icon_scope) // INOUT BUS [35:0]
    ) /* synthesis syn_noprune=1 */;

    cs_ila_1024 CS_ILA ( .CONTROL(cs_icon_scope),
        .CLK(clk),
        .DATA( trace ), // IN BUS [1023:0]
        .TRIG0( CS_TRIG0 ), // IN BUS [31:0]
        .TRIG1( CS_TRIG1 ), // IN BUS [31:0]
        .TRIG2( CS_TRIG2 ), // IN BUS [31:0]
        .TRIG3( CS_TRIG3 )  // IN BUS [31:0]
    ) /* synthesis syn_noprune=1 */;
end endgenerate //COLT45_SCOPE


// SIMULATION ONLY business

// synthesis translate_off

generate if (COLT45_STEPMAX) begin:_STEPS_
    reg [15:0] DBG_cycle, DBG_step;
    initial begin
        $display ("%m");
        $display ("-   -   -   -   -   -   -   -   -   -   -   -");
    end

    task DO_FINISH; begin
        $display("Ran %d / %d", DBG_cycle, DBG_step);
        $display("");
        regfile.DUMP();
        $stop();
    end endtask

    always@(rst, stall) begin
        $display("=================================================================");
        $display("CTL-: C %h  R %h  S %h", clk, rst, stall);
        $strobe ("CTL+: C %h  R %h  S %h", clk, rst, stall);
        $strobe ("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
        if (rst) begin
            DBG_cycle = 'bz;  DBG_step = 'bz;
            if (COLT45_CONTROL) $monitor(" (%d) CTL DX %b", DBG_cycle, IControlDX_);
        end else if (DBG_cycle[0] === 1'bz) begin
            DBG_cycle = 0;  DBG_step = 0;
        end
    end

    always@(posedge clk) if (DBG_cycle >= 0) begin:DBG_RUN_POS
        $display(" REG1:R(%h,%d)=%h(%d)", REGFILE_ra1, REGFILE_ra1, REGFILE_rd1, REGFILE_rd1);
        if (FWD_1) $display(" *FWD1:      >>%h(%d)", FWD_rd1, FWD_rd1);
        $display(" REG2:R(%h,%d)=%h(%d)", REGFILE_ra2, REGFILE_ra2, REGFILE_rd2, REGFILE_rd2);
        if (FWD_2) $display(" *FWD2:      >>%h(%d)", FWD_rd2, FWD_rd2);

        $display("%d]   /DX: %h %h", DBG_cycle, PC_F_, INST_F_);
        $display("%d]  /MW : %h<=%h", DBG_cycle, MemAddr__MW, MemWValue__MW);
        $display("%d]  /MW : %b", DBG_cycle, IControl__MW);
        $display("%d] /F  : R[%h,%d]<=%h(%d)", DBG_cycle, WBK_Reg_MW2DX_, WBK_Reg_MW2DX_,
                            WBK_Val_MW2DX_, WBK_Val_MW2DX_);

        DBG_cycle = DBG_cycle + 1;
        if (!stall) DBG_step = DBG_step + 1;
        if (DBG_step >= (COLT45_STEPMAX)) DO_FINISH();
        #1;

        $display("%d]/= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\", DBG_cycle);
        $display("%d] RST: %d   STL: %d   STEP: %d", DBG_cycle, rst, stall, DBG_step);
        $display("%d]    /F: %h *%d", DBG_cycle, BRA_PCBranch_DX2F_, BRA_DoBranch_DX2F_);
        $display("%d]  F/DX: %h %h #%d", DBG_cycle, PC_DX, INST_DX, CNT_Inst);
        $display("%d]DX/MW : %h <=%h", DBG_cycle, PC_MW, RegWValue_MW);
        $display("%d]      : %b", DBG_cycle, IControl_MW); // Make a task to break into fields
        $strobe ("%d] -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -", DBG_cycle);
    end
end endgenerate //COLT45_STEPMAX

task DUMP_PC; begin
    $display("PC: [%d] PC_DX=%h INST_DX=%h PC_MW=%h", CNT_Inst, PC_DX, INST_DX, PC_MW);
end endtask

generate if (COLT45_PC) begin:_PC_
    always@(posedge clk) if (!stall && !rst) begin
        DUMP_PC();
    end
end endgenerate //COLT45_PC

generate if (COLT45_REGREAD) begin:_REGREAD_ //REG reads are async, but only "care" at clock edge
    always@(posedge clk) if (!rst) begin
        if (REGFILE_ra1 != 0) begin
            $display(" reg1:FWD=%b R1(%h,%d)=%h (%d)", FWD_1, REGFILE_ra1, REGFILE_ra1, FWD_rd1, FWD_rd1);
        end
        if (REGFILE_ra2 != 0) begin
            $display(" reg2:FWD=%b R2(%h,%d)=%h (%d)", FWD_2, REGFILE_ra2, REGFILE_ra2, FWD_rd2, FWD_rd2);
        end
    end
end endgenerate

generate if (COLT45_MEMWRITE) begin:_MEMWRITE_
    always@(posedge clk) if (!stall && |_WriteMask) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        $display("** [%h,%d] <= %h(%d) {%b}",
            MemAddr__MW, MemAddr__MW, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddr__MW[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
    end
end endgenerate

generate if (COLT45_SCRATCH) begin:_SCRATCH_
    always@(posedge clk) if (!stall && _hot_DB) begin
        $display("\n=============");
        DUMP_PC();
        $display("TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddr__MW[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
        if (|_WriteMask) begin
            regfile.DUMP();
            $display("[%h,%d] <<= %h(%d) {%b}",
                MemAddr__MW, MemAddr__MW, _WDataMasked, _WDataMasked, _WriteMask);
        end else begin
            $display("[%h,%d] ==> %h(%d)",
                MemAddr__MW, MemAddr__MW, RData_DB, RData_DB);
        end
        $display("=============\n");
    end
end endgenerate

// synthesis translate_on

`else //COLT45_KILLFUN (either def/ndef check)

assign trace = 1024'd0;

`endif //COLT45_KILLFUN (either def/ndef check)

endmodule
