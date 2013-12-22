`include "cpuglobal.vh"

module MIPS150 #(
    parameter DD=`COLT45_DD,
    parameter ClockFreq=50_000_000,
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
    input [31:0] instruction,
    input stall,

// CP4+
    output [31:0] gp_code,
    output [31:0] gp_frame,
    output gp_valid,
    input frame_interrupt,

//BRK tap (will become internal instead)
    input brk,
    output [0:1023] trace,
    inout  [35: 0] SCOPE_CPU
);

    localparam ENABLE_BRK=0, ENABLE_SCOPE=0;

// CP4+
    assign gp_code=32'd0, gp_frame=32'd0;
    assign gp_valid = 1'b0;

    // Global sorts of things
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun TUN_CPUGlobal // Drive CPUGlobal bus from CPU module inputs
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );


/*
  NAMING CONVENTIONS: (might be inconsistent/in-flux though :)
    SUFFIX for stage code (WF, DX, M) == (WriteBack-InstFetch, Decode-Execute, Memory)
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
    wire         #DD DOBranch_DX_WF_; // The "W" (writeback) and branch lives near the M-Stage
    wire [31: 0] #DD PCBranch_DX_WF_; // because they carry forward/backward from there but
    wire [ 4: 0] #DD WBKReg_M_WF_;    // this is a "WF" stage because impact is "timed" to
    wire [31: 0] #DD WBKDat_M_WF_;    // correlate with fetch & is "behind" aligned pipeline regs.
    wire         #DD WBKCanFWD_M_WF_; // *Overeager forwarding created a monster-slow MDX-stage!
//TODO: Make "foward declares" consistent: all UP-here or all ALAP for use

    // Declare outputs of WF stage
    wire [31: 0] INST_ADDR;
    wire [31: 0] CycleCount, StallCount, StepCount;
    StageWF #(
        .COUNTERWIDTH(32)//, .BOOTPC(32'h6_000_0000) //TODO: Change back to default/BIOS
    ) s_WF ( .CPUGlobal(CPUGlobal),
        .DOBranch(DOBranch_DX_WF_), .PCBranch(PCBranch_DX_WF_),
        .PC(INST_ADDR),
        .CycleCount(CycleCount), .StallCount(StallCount), .StepCount(StepCount)
    );
    wire [31: 0] INST_DATA; //Instruction fetch is sync'd here but handled by StageM
//TODO: Declare related "async" line & rename this for stage-of-origin


//=============| PIPELINE-BORDER: WF/DX >>>=============
    wire [31: 0] INST_DX;
    //NOTE: INST_DATA gets changed early by BRAM (no disable availabe) so latch not register
    PipelineRegister #( .Width(32), .Mode(1) ) // Registered for us in prior stage
        REG_INST_DX ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX) );
    wire [31: 0] PC_DX;
    PipelineRegister #( .Width(32), .Mode(0) )
        REG_PC_DX   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX) );
//=============<<< PIPELINE-BORDER: WF/DX |=============


    // REGFILE async-read via DX-stage but sync-write via M-stage WB
    wire [ 4: 0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
    wire [31: 0] REGFILE_rd1, REGFILE_rd2, REGFILE_wd;
    assign REGFILE_wa = WBKReg_M_WF_, REGFILE_wd = WBKDat_M_WF_;
    wire REGFILE_we = ~stall && (REGFILE_wa != 0); // Mute "we" if "wa"==0 for signal clarity
    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .we(REGFILE_we), .wa(REGFILE_wa), .wd(REGFILE_wd),
        // Read is asynchronous & always enabled (even during stall)
        .ra1(REGFILE_ra1), .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2), .rd2(REGFILE_rd2)
    );
    // FORWARDING calculation (a "virtual" behavior tacked onto REGFILE)
    wire FWD_Allow = WBKCanFWD_M_WF_; // Has already checked for "wa"==0 elsewhere
    wire FWD_1 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra1) : 1'b0;
    wire FWD_2 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra2) : 1'b0;
    wire [31: 0] #DD FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] #DD FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // COPROCESSOR async-read via DX-stage (like REGFILE) but sync-write from REGFORWARD
    wire         CopInHot;
    wire [ 4: 0] CopAddr;
    wire [31: 0] CopOut;
    // COP0 lines for control/branch
    // COP0 lines for peripherals
    COP0150 cop0 (
        .Clock(clk), .Reset(rst), .Enable(1'b0), //TODO: ENABLE! Disable until handled?
        .DataAddress(CopAddr), //IN-5 (Cop Register to read/write)
        .DataOut(CopOut), //OUT-32 (Injected into StageDX.RegWValue_)
        .DataInEnable(CopInHot), //IN (mtc0)
        .DataIn(FWD_rd2), //IN-32 (Always fed, only used if enabled)
        .InterruptedPC(), //IN-32 (PC_DX or similar)
        .InterruptHandled(), //IN (Acknowledge the branch is happening)
        .InterruptRequest(), //OUT (Like a branch)
        .UART0Request(), //IN (edge detect can-write)
        .UART1Request() //IN (edge detect can-read)
    );
    //TODO: Pick correct PC to stash
    //TODO: Time handling around branches & acknowledge
    //TODO: UART FSMs/Gates (for edges)

    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] MemAddrDX_, MemWValueDX_, RegWValueDX_;
    StageDX s_DX
    ( //.CPUGlobal(CPUGlobal),
        //Async regfile reads & COP access
        .REG_R1_(REGFILE_ra1), .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2), .REG_D2_(FWD_rd2),
        .CopAddr(CopAddr), .CopOut(CopOut), .CopInHot(CopInHot),
        //Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Outputs
        .IControl_(IControlDX_),
        .MemAddr_(MemAddrDX_), .MemWValue_(MemWValueDX_),
        .RegWValue_(RegWValueDX_),
        //Feedbacks
        .DOBranch_(DOBranch_DX_WF_), .PCBranch_(PCBranch_DX_WF_)
    );


//=============| PIPELINE-BORDER: DX/M >>>=============
    `BUS_ICTL_type IControl__M;
    wire  [31: 0]   MemAddr__M;
    wire  [31: 0]   MemWValue__M;
    PipelineRegister #( .Width(`BUS_ICTL_width), .Mode(1) ) //NOTE:MODE-3 vs MODE-1
        REG_IControl__M ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl__M ) );
    PipelineRegister #( .Width(32),              .Mode(1) ) //NOTE:MODE-3 vs MODE-1
        REG_MemAddr__M  ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr__M  ) );
    PipelineRegister #( .Width(32),              .Mode(1) ) //NOTE:MODE-3 vs MODE-1
        REG_MemWValue__M( .CPUGlobal(CPUGlobal),    .In(MemWValueDX_),  .Out(MemWValue__M) );
    `BUS_ICTL_type IControl_M;
    wire  [31: 0]   MemAddr_M;
    wire  [31: 0]   RegWValue_M;
    wire  [31: 0]   PC_M;
    PipelineRegister #( .Width(`BUS_ICTL_width) )
        REG_IControl_M  ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl_M  ) );
    PipelineRegister #( .Width(32) )
        REG_MemAddr_M   ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr_M   ) );
    PipelineRegister #( .Width(32) )
        REG_RegWValue_M ( .CPUGlobal(CPUGlobal),    .In(RegWValueDX_),  .Out(RegWValue_M ) );
    PipelineRegister #( .Width(32) ) //TODO: Use simple flag for "in-bios/allow-I-write"
        REG_PC_M        ( .CPUGlobal(CPUGlobal),    .In(PC_DX       ),  .Out(PC_M        ) );
//=============<<< PIPELINE-BORDER: DX/M |=============


    // MEMORY/MMIO patchwork lines ("setups" prefixed with "_", "results" not)
    wire _hot_IO, _hot_BR, _hot_DC, _hot_IC, _hot_DB, _hot_IB, _hot_ISR;
    wire [ 3: 0] _WriteMask, _ByteMask;
    wire [31: 0] _WDataMasked;
    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB, RData_ISR;
    wire [31: 0] INST_BR, INST_IC, INST_IB, INST_ISR;
    StageM s_M
    ( //.CPUGlobal(CPUGlobal),
        //Inputs
        ._IControl  (IControl__M),  .IControl   (IControl_M),
        ._MemAddr   (MemAddr__M),   .MemAddr    (MemAddr_M),
        ._MemWValue (MemWValue__M), .RegWValue  (RegWValue_M),
        .PC         (PC_M), //TODO: Just pass "in-bios" flag & pass PC-to-fetch
        //Feedbacks to "prior" stages (forwarding & instruction fetch)
        .WBK_Reg_   (WBKReg_M_WF_), .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_),
//      TODO: .PC_DATA fetched
        //Memory/MMIO "pre-clock" drives OUT
        ._hot_IO(_hot_IO), ._hot_BR(_hot_BR), ._hot_DC(_hot_DC),
        ._hot_IC(_hot_IC), ._hot_DB(_hot_DB), ._hot_IB(_hot_IB),
        ._hot_ISR(_hot_ISR),
        ._WriteMask(_WriteMask), ._WDataMasked(_WDataMasked), ._ByteMask(_ByteMask),
        //Memory/MMIO "post-clock" results IN
        .RData_IO(RData_IO), .RData_BR(RData_BR), .RData_DC(RData_DC),
        .RData_DB(RData_DB), .RData_ISR(RData_ISR)
    );
//TODO: Move into StageM & mux all sources
    wire _hoti_BR = (INST_ADDR[31:28] == 4'h4);
    assign INST_DATA = (_hoti_BR) ? INST_BR : INST_IB;

    // MEMORY/MMIO ELEMENTS (straddle M-WF-stages & interface outside CPU)
//TODO: House these in new MEMIOPlex

//TODO: Debug trailing "zero" on DDR send test output
    //TODO: Ensure this doesn't trigger double-reads/writes from stall nuances
    //NOTE: DRAM addrs rollorver @ 0x0200_0000 but CPU need only clip top nibble here.
    assign dcache_addr = {4'h0, MemAddr__M[27:0]},
        dcache_we   = (_hot_DC) ? (_WriteMask) : 4'b0000,
        dcache_din  = _WDataMasked,
        dcache_re   = _hot_DC && !(|_WriteMask),
        RData_DC    = dcache_dout;
//    assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0, RData_DC=32'd0;

    //NOTE: Both _hot_DC && _hot_IC ARE allowed to be active simultaneously for WRITE
    //      but writability rules prevent INST-read & DATA-write collision
    assign icache_addr = {4'h0, (_hot_IC) ? MemAddr__M[27:0] : INST_ADDR[27:0]},
        icache_we   = (_hot_IC) ? (_WriteMask) : 4'b0000,
        icache_din  = _WDataMasked,
        icache_re   = (INST_ADDR[31:28] == 4'b0001),
        INST_IC     = instruction;
//    assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0, INST_IC =32'd0;

    isr_mem bram_isr
    ( .clka(clk), .ena(~stall && _hot_ISR),
        .addra(MemAddr__M[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_ISR)
    ) /* synthesis syn_noprune=1 */;

    bios_mem brom_bios
    ( .clka(clk), .ena(~stall && _hot_BR),
        .addra(MemAddr__M[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/

    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
        .enb(_hoti_BR), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

    dmem_blk_ram bram_dmem
    ( .clka(clk), .ena(~stall && _hot_DB),
        .addra(MemAddr__M[13:2]),
        .douta(RData_DB),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked)
    ) /* synthesis syn_noprune=1 */;

    imem_blk_ram bram_imem
    ( .clka(clk), .ena(~stall && _hot_IB),
        .addra(MemAddr__M[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch (sic :)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB)
    ) /* synthesis syn_noprune=1 */;

    //TODO: Rename MEMIOPlex := UARTRVA (new MEMIOPlex houses MEM/MMIO)
    `BUS_SHAKE_type(8) UATX, UARX;
    MEMIOPlex iomap_uart
    ( .clk(clk), .rst(rst), .ena(~stall && _hot_IO),
        .addra(MemAddr__M[13:2]),
        .douta(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
        .RVA_RX(UARX), .RVA_TX(UATX)
    );
    wire Rx_Ready, Rx_Valid, Tx_Valid, Tx_Ready;
    wire [7:0] Rx_Data, Tx_Data;
    BUS_SHAKE_tun #(.InWidth(8)) TUN_SHAKE_Rx
    ( ._BUS_(UARX),
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );
    BUS_SHAKE_tap #(.InWidth(8)) TAP_SHAKE_Tx
    ( ._BUS_(UATX),
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );
    UART #(.ClockFreq(ClockFreq)) uart
    ( .Clock(clk), .Reset(rst),
        // Receiver     (handshakes go both in/out)
        .SIn(FPGA_SERIAL_RX),
        .DataOut(Rx_Data), .DataOutValid(Rx_Valid), .DataOutReady(Rx_Ready),
        // Transmitter  (handshakes go both in/out)
        .SOut(FPGA_SERIAL_TX),
        .DataIn(Tx_Data), .DataInValid(Tx_Valid), .DataInReady(Tx_Ready)
    );



//=============DEBUGGING TOOLS BELOW THIS POINT=============

/*
//For examining waveform/timing impact of each variation simultaneously
    wire [31: 0] PC_DX0, PC_DX1, PC_DX2, PC_DX3;
    wire [31: 0] INST_DX0, INST_DX1, INST_DX2, INST_DX3;
    PipelineRegister #( .Width(32), .Mode(0) )
        REG_PC_DX0   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX0) );
    PipelineRegister #( .Width(32), .Mode(1) )
        REG_PC_DX1   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX1) );
    PipelineRegister #( .Width(32), .Mode(2) )
        REG_PC_DX2   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX2) );
    PipelineRegister #( .Width(32), .Mode(3) )
        REG_PC_DX3   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX3) );
    PipelineRegister #( .Width(32), .Mode(0) )
        REG_INST_DX0 ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX0) );
    PipelineRegister #( .Width(32), .Mode(1) )
        REG_INST_DX1 ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX1) );
    PipelineRegister #( .Width(32), .Mode(2) )
        REG_INST_DX2 ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX2) );
    PipelineRegister #( .Width(32), .Mode(3) )
        REG_INST_DX3 ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX3) );
*/

`ifdef ENABLE_BRK
assign trace = { // 4 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
    // 0 \\             // 1 \\             // 2 \\             // 3 \\
    PC_DX,              INST_DX,            StepCount,          PCBranch_DX_WF_,
    FWD_rd1,            FWD_rd2,            REGFILE_wd,
        {FWD_1,2'b00,REGFILE_ra1, FWD_2,2'b00,REGFILE_ra2,
            REGFILE_we,FWD_Allow,1'b0,REGFILE_wa,
            _hot_IO,_hot_BR,_hot_IC,_hot_DC,_hot_IB,_hot_DB,~rst,stall},

    RData_IO,           RData_BR,           RData_DC,           RData_DB,
    MemAddr_M,          MemAddr__M,         _WDataMasked,
        {16'h1234,
            _WriteMask,_ByteMask,2'b00,_hot_IB,_hot_DB,_hot_IO,_hot_BR,_hot_IC,_hot_DC},

    INST_ADDR,          INST_DATA,          StallCount,         PC_M,
    {9'd0,IControlDX_}, 32'd0,              {9'd0,IControl_M},  {9'd0,IControl__M},

    256'd0
};
`endif //ifdef ENABLE_BRK

`ifdef ENABLE_SCOPE
// Having constraint trouble when attempting ILA inclusion (some signals getting munched out???)
wire [1023:0] scoper = { // 4 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
    // 0 \\             // 1 \\             // 2 \\             // 3 \\
    PC_DX,              INST_DX,            StepCount,          PCBranch_DX_WF_,
    FWD_rd1,            FWD_rd2,            REGFILE_wd,
        {FWD_1,2'b00,REGFILE_ra1, FWD_2,2'b00,REGFILE_ra2,
            REGFILE_we,FWD_Allow,1'b0,REGFILE_wa,
            _hot_IO,_hot_BR,_hot_IC,_hot_DC,_hot_IB,_hot_DB,~rst,stall},

    32'd0,              32'd0,              32'd0,              32'd0,
    32'd0,              32'd0,              32'd0,              32'd0,
/*
    RData_IO,           RData_BR,           RData_DC,           RData_DB,
    32'd0,              latchedADDR,        latchedDATA,
    {16'h1234,
            latchedMASK,4'd0,2'b00,_hot_IB,_hot_DB,_hot_IO,_hot_BR,_hot_IC,_hot_DC},
*/

    INST_ADDR,          INST_DATA,          StallCount,         PC_M,
    {9'd0,IControlDX_}, 32'd0,              {9'd0,IControl_M},  {9'd0,IControl__M}

};

//wire [767:0] CS_DATA = scoper[767:0]  /* synthesis syn_noprune=1 */;
wire [36:0] CS_TRIG0 = {5'd0, FWD_1,2'b00,REGFILE_ra1, FWD_2,2'b00,REGFILE_ra2,
                        REGFILE_we,FWD_Allow,1'b0,REGFILE_wa,
                        _hot_IO,_hot_BR,_hot_IC,_hot_DC,
                        _hot_IB,_hot_DB,~rst,stall};
wire [36:0] CS_TRIG1 = {5'd0, PC_DX};
wire [36:0] CS_TRIG2 = {5'd0, INST_DX};
wire [36:0] CS_TRIG3 = {5'd0, StepCount};
cs_ila_1024 CS_ILA ( .CONTROL(SCOPE_CPU),
    .CLK(clk),
    .DATA( scoper ), // IN BUS [767:0]
    .TRIG0( CS_TRIG0 ), // IN BUS [36:0]
    .TRIG1( CS_TRIG1 ), // IN BUS [36:0]
    .TRIG2( CS_TRIG2 ), // IN BUS [36:0]
    .TRIG3( CS_TRIG3 )  // IN BUS [36:0]
) /* synthesis syn_noprune=1 */;
`endif //ifdef ENABLE_SCOPE


// synthesis translate_off
generate if (COLT45_STEPMAX > 0) begin:_STEPS_
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

        $display("%d]   /DX: %h %h", DBG_cycle, INST_ADDR, INST_DATA);
        $display("%d]  /M  : %h<=%h", DBG_cycle, MemAddr__M, MemWValue__M);
        $display("%d]  /M  : %b", DBG_cycle, IControl__M);
        $display("%d] /WF : R[%h,%d]<=%h(%d)", DBG_cycle, WBKReg_M_WF_, WBKReg_M_WF_,
                            WBKDat_M_WF_, WBKDat_M_WF_);

        DBG_cycle = DBG_cycle + 1;
        if (!stall) DBG_step = DBG_step + 1;
        if (DBG_step >= (COLT45_STEPMAX)) DO_FINISH();
        #1;

        $display("%d]/= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\", DBG_cycle);
        $display("%d] RST: %d   STL: %d   STEP: %d", DBG_cycle, rst, stall, DBG_step);
        // DOBranch_DX_WF_
        $display("%d]   /WF: %h *%d", DBG_cycle, PCBranch_DX_WF_, DOBranch_DX_WF_);
        $display("%d] WF/DX: %h %h #%d", DBG_cycle, PC_DX, INST_DX, StepCount);
        $display("%d] DX/M : %h <=%h", DBG_cycle, PC_M, RegWValue_M);
        $display("%d]      : %b", DBG_cycle, IControl_M); // Make a task to break into fields
        $strobe ("%d] -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -", DBG_cycle);
    end
end endgenerate

task DUMP_PC; begin
    $display("PC: [%d] PC_DX=%h INST_DX=%h PC_M=%h", StepCount, PC_DX, INST_DX, PC_M);
end endtask

generate if (COLT45_PC) begin:_PC_
    always@(posedge clk) if (~stall && ~rst) begin
        DUMP_PC();
    end
end endgenerate

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
    always@(posedge clk) if (~stall && |_WriteMask) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        $display("** [%h,%d] <= %h(%d) {%b}",
            MemAddr__M, MemAddr__M, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddr__M[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
    end
end endgenerate

generate if (COLT45_SCRATCH) begin:_SCRATCH_
    always@(posedge clk) if (~stall && _hot_DB) begin
        $display("\n=============");
        DUMP_PC();
        $display("TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddr__M[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
        if (|_WriteMask) begin
            regfile.DUMP();
            $display("[%h,%d] <<= %h(%d) {%b}",
                MemAddr__M, MemAddr__M, _WDataMasked, _WDataMasked, _WriteMask);
        end else begin
            $display("[%h,%d] ==> %h(%d)",
                MemAddr__M, MemAddr__M, RData_DB, RData_DB);
        end
        $display("=============\n");
    end
end endgenerate

// synthesis translate_on

endmodule
