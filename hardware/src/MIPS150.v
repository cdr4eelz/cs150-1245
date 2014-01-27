`include "cpuglobal.vh"

module MIPS150 #(
    parameter DD=`COLT45_DD,
    parameter ClockFreq=50_000_000,
    parameter COLT45_BRK=0, COLT45_SCOPE=1, COLT45_SCRATCH=0, COLT45_PC=0,
                COLT45_REGREAD=0, COLT45_MEMWRITE=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
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
    input frame_interrupt,

input [31:0] DBG_MEM150
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
    SUFFIX for stage code (F, DX, MW) == (instFetch, Decode/regread-eXecute, Memory-Writeback)
    xxxSS_  : Value unstable during given stage (valid by end-of-cycle if !stall)...
        Typical stage/module output headed via pipeline register to next stage.
    xxx_SS  : Value stable during entire given stage including during stall...
        Typical stage/module input via pipeline register from by "prior" stage or "feedback".
    xxx_SS_ : As with SS_ except is already REGISTER'd at exit of output stage.
WRONG?  OUTPUT is FROM an internal component that is unavoidably synchronous (maybe not stallproof).
    xxx__SS : Redundant with xxxSS_ except is named relative to the inbound stage.
        From this point of view, peeking into prior stage to setup pre-clock input to sync.
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
    wire         #DD BRA_IRQPending_DX2F_;
    wire [ 4: 0] #DD WBK_Reg_MW2DX_;
    wire [31: 0] #DD WBK_Val_MW2DX_;
    wire         #DD WBK_CanFWD_MW2DX_;
    wire         #DD CNT_Reset_MW2F_;

    // Memory lines
    wire [31: 0] IMEM_ADDR, DMEM_ADDR;
    wire [31: 0] IMEM_DATA, DMEM_DATA;

    // Declare outputs of F stage
    wire [31: 0] PC_F_, PCNEXT_F_;
    wire [31: 0] INST_F_;
    wire [63: 0] CNT_Cycle, CNT_Inst, CNT_Stall, CNT_BRANCH, CNT_ISR;
    wire WAS_Running, WAS_Stall, WAS_Inst, WAS_Branch, WAS_ISR;
    wire DO_ISR = BRA_IRQPending_DX2F_ && !(WAS_Branch || WAS_ISR); //Check STALL???
    StageF #(
        .COUNTERWIDTH(64)
    ) s_F ( .clk(clk), .rst(rst), .stall(stall),
        //Inputs (feedback from other stages)
        ._DoBranch(BRA_DoBranch_DX2F_), ._PCBranch(BRA_PCBranch_DX2F_),
        ._ResetCounters(CNT_Reset_MW2F_), ._DoISR(DO_ISR),
        //Outputs (toward next stage)
        .PC_(PC_F_), .INST_(INST_F_), .PCNEXT_(PCNEXT_F_),
        //CPU Counters & Prior-state flags
        .CNT_CYCLE(CNT_Cycle), .CNT_INST(CNT_Inst), .CNT_STALL(CNT_Stall),
        .CNT_BRANCH(CNT_BRANCH), .CNT_ISR(CNT_ISR),
        .WAS_RUNNING(WAS_Running), .WAS_INST(WAS_Inst),
        .WAS_STALL(WAS_Stall), .WAS_BRANCH(WAS_Branch), .WAS_ISR(WAS_ISR),
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
    wire REGFILE_we = !stall && (REGFILE_wa != 0); // Mute "we" if "wa"==0 for signal clarity */
    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .we(REGFILE_we), .wa(REGFILE_wa), .wd(REGFILE_wd),
        // Read is asynchronous & always enabled (even during stall...MUST hold ra1/2 steady)
        .ra1(REGFILE_ra1), .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2), .rd2(REGFILE_rd2)
    );
    // FORWARDING calculation
    wire FWD_Allow = (REGFILE_wa != 0) ? WBK_CanFWD_MW2DX_ : 1'b0;
    wire FWD_1 = FWD_Allow && (REGFILE_wa == REGFILE_ra1);
    wire FWD_2 = FWD_Allow && (REGFILE_wa == REGFILE_ra2);
    wire [31: 0] #DD FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] #DD FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // COPROCESSOR async-read via DX-stage (like REGFILE) but sync-write from REGFORWARD
    wire [ 4: 0] CopAddr;
    wire [31: 0] CopOut;
    wire CopInHot, IRQUART0, IRQUART1;
    COP0150 cop0 (
        .Clock(clk), .Reset(rst), .Enable(1'b1), //TODO:CONFIRM Enabled even during stall???
        .DataAddress(CopAddr), //IN-5 (Cop Register to read/write)
        .DataOut(CopOut), //OUT-32 (Injected into StageDX.RegWValue_)
        .DataInEnable(!stall && CopInHot), //IN (mtc0)
        .DataIn(FWD_rd2), //IN-32 (Always fed, only used if enabled)
        .InterruptedPC(PCNEXT_F_), //IN-32 (PCNEXT_F_ was supersceeded by ISRPC)
        .InterruptHandled(!stall && WAS_ISR), //IN (Acknowledge the ISR is happening)
        .InterruptRequest(BRA_IRQPending_DX2F_), //OUT (Like a branch to fixed address)
        .UART0Request(IRQUART0), .UART1Request(IRQUART1) //IN (edge detect "pulse")
    );

    // Declare outputs of DX stage
    wire [31: 0] MemAddrDX_, RegWValueDX_, MemWValueDX_;
    wire [ 4: 0] DestRegDX_;
    wire [ 1: 0] MemShiftDX_;
    wire         MemToRegDX_, MemWriteDX_;
    StageDX s_DX
    ( //NOTE: Currently combinational: .clk(clk), .rst(rst), .stall(stall),
        //Async regfile reads & COP access
        .REG_R1_(REGFILE_ra1),  .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2),  .REG_D2_(FWD_rd2),
        .CopAddr(CopAddr), .CopOut(CopOut), .CopInHot(CopInHot),
        //Stage Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Global control signals
        .DestReg_(DestRegDX_),
        .MemShift_(MemShiftDX_), .MemSigned_( /*Unimplemented*/ ),
        .MemToReg_(MemToRegDX_), .MemWrite_(MemWriteDX_),
        //Stage Outputs
        .MemAddr_(MemAddrDX_), .RegWValue_(RegWValueDX_),
        .MemWValue_(MemWValueDX_),
        //Feedback outputs
        .DOBranch_(BRA_DoBranch_DX2F_), .PCBranch_(BRA_PCBranch_DX2F_)
    );


//===============| PIPELINE-BORDER: DX/M >>>=============
    assign DMEM_ADDR = MemAddrDX_;
    wire  [31: 0]   MemAddr_MW;
    wire  [31: 0]   RegWValue_MW;
    wire  [ 4: 0]   DestReg_MW;
    wire  [ 1: 0]   MemShift_MW;
    wire            MemToReg_MW;
    PipelineRegister #( .Width(32) )
        PIPR_MemAddr_MW   ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(MemAddrDX_  ),  .Out(MemAddr_MW   ) );
    PipelineRegister #( .Width(32) )
        PIPR_RegWValue_MW ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(RegWValueDX_),  .Out(RegWValue_MW ) );
    PipelineRegister #( .Width(5) )
        PIPR_DestReg_MW   ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(DestRegDX_ ),  .Out(DestReg_MW   ) );
    PipelineRegister #( .Width(2) )
        PIPR_MemShift_MW  ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(MemShiftDX_),  .Out(MemShift_MW  ) );
    PipelineRegister #( .Width(1) )
        PIPR_MemToReg_MW  ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(MemToRegDX_),  .Out(MemToReg_MW  ) );
//Debug use only
    wire  [31: 0]   PC_MW;
    PipelineRegister #( .Width(32) ) //NOTE: Only need 1 bit, but full value nice for debugging
        PIPR_PC_MW        ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(PC_DX       ),  .Out(PC_MW        ) );
//=============<<< PIPELINE-BORDER: DX/M |===============

    // MEMORY/MMIO patchwork lines ("setups" prefixed with "_", "results" not)
    wire [ 3: 0] _WriteMask;
    wire [31: 0] _WDataMasked;
    StageMW s_MW
    ( //NOTE: Currently combinational: .clk(clk), .rst(rst), .stall(stall),
        // Inputs (pre-clock setup)
        ._MemShift(MemShiftDX_), ._MemAddrShift(DMEM_ADDR[1:0]),
        ._MemWValue(MemWValueDX_), ._MemWrite(MemWriteDX_),
        // Inputs (post-clock results)
        .MemShift_MW(MemShift_MW), .MemAddrShift_MW(MemAddr_MW[1:0]),
        .RDataRaw(DMEM_DATA),
        .DestReg_MW(DestReg_MW), .MemToReg_MW(MemToReg_MW),
        .RegWValue_MW(RegWValue_MW),
        //Feedbacks to "prior" stages (forwarding & instruction fetch)
        .WBK_Reg_(WBK_Reg_MW2DX_), .WBK_Val_(WBK_Val_MW2DX_),
        .WBK_CanFWD_(WBK_CanFWD_MW2DX_),
        //Memory/MMIO "pre-clock" drives OUT/IN
        ._WriteMask(_WriteMask), ._WDataMasked(_WDataMasked)
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
    //Not all instruction-fetch "drives" usable by memories themselves
    wire hoti_BR_  = hoti_[2]; //TODO: Consider this for PCinBIOS test
    wire hoti_IC_  = hoti_[1];

    wire PCinBIOSDX_ = (PC_DX[31:28]==4'b0100); //Borrow value from other stage (close enough)
    reg _hot_IO, _hot_BR, _hot_DC, _hot_IC, _hot_ISR;
    reg _hot_IB, _hot_DB;
    always @(*) begin
        {_hot_IO,_hot_BR,_hot_DC,_hot_IB,_hot_DB,_hot_IC,_hot_ISR} = 0;
        if (MemToRegDX_ || MemWriteDX_) begin
            case (DMEM_ADDR[31:28])
                4'b1000: _hot_IO = 1'b1;
                4'b0100: _hot_BR = !MemWriteDX_; //Read-only
                4'b0011: begin
                        _hot_DC = 1'b1;
                        _hot_IC = MemWriteDX_ && PCinBIOSDX_;
                    end
                4'b0010: _hot_IC = MemWriteDX_ && PCinBIOSDX_;
                4'b0001: _hot_DC = 1'b1;
`ifndef COLT45_STRICT
                4'b0110: _hot_IB = MemWriteDX_; //XTRA: Scratchpad-DMEM
                4'b0101: _hot_DB = 1'b1; //XTRA: Scratchpad-DMEM
`endif //(!) COLT45_STRICT
                4'b1100: _hot_ISR = MemWriteDX_; //ISR//
            endcase
        end
    end


reg [3:0] P_hoti;
always @(posedge clk) begin:_REG_HOTI_
    if (!stall) P_hoti <= hoti_;
end

    wire [31: 0] INST_ISR, INST_BR, INST_IC, INST_IB;
    reg  [31: 0] MUX_IMEM;
    always @(*) begin:_MUX_IMEM_ //Drive instruction from appropriate memory component
        case (P_hoti)
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

    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB;
    reg [31:0] MUX_DMEM; // Registered elsewhere (is just a reg here because of always@*)
    always @(*) begin:_MUX_DMEM_
        case (MemAddr_MW[31:28])
            4'b1000: MUX_DMEM = RData_IO;
            4'b0100: MUX_DMEM = RData_BR;
            4'b0011: MUX_DMEM = RData_DC;
            4'b0001: MUX_DMEM = RData_DC;
`ifndef COLT45_STRICT //TODO: Ensure no other references to these if STRICT mode!
            4'b0101: MUX_DMEM = RData_DB; // Scratchpad-RAM
`endif
            default: MUX_DMEM = 32'd0;
        endcase // CAUTIOUS trapping of EVERY case
    end
    assign DMEM_DATA = MUX_DMEM;


    // MEMORY/MMIO ELEMENTS (straddle MW & F stages & interface outside CPU)

//TODO: Apply selector to _WriteMask with repeat-concat and an AND
//TODO: Ideally generate "isRead" signal WHILE generating _WriteMask

reg [31:0] P_dcache_addr;
reg P_dcache_re;
always @(posedge clk) begin
    P_dcache_addr <= dcache_addr;
    P_dcache_re <= dcache_re;
end
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
    REGFILE_we,REGFILE_wa[4:0],REGFILE_ra2[4:0], REGFILE_ra1[4:0],
    FWD_Allow,FWD_2,FWD_1,DBG_MEM150[31],
        _hot_IO,_hot_BR,_hot_IC,_hot_DC,
        hoti_[3:0],
        rst,BRA_IRQPending_DX2F_,BRA_DoBranch_DX2F_,stall
};

assign trace = {
// 3 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
    // 0 \\             // 1 \\             // 2 \\             // 3 \\
    PC_DX[31:0],        INST_DX[31:0],      CNT_Inst[31:0],     BRA_PCBranch_DX2F_[31:0],
    REGFILE_wd[31:0],   FWD_rd2[31:0],      FWD_rd1[31:0],      keywatch[31:0],

    RData_IO[31:0],     RData_BR[31:0],     RData_DC[31:0],     RData_DB[31:0],
    MemAddr_MW[31:0],   MemAddrDX_[31:0],   _WDataMasked[31:0],
    {   _hot_IO,_hot_BR,_hot_IC,_hot_DC, 1'b0,_hot_ISR,_hot_IB,_hot_DB,
        dcache_we, 3'd0,dcache_re,
        icache_we, 3'd0,icache_re,
        _WriteMask ,WAS_ISR,WAS_Stall,WAS_Inst,WAS_Branch
    },

    IMEM_ADDR[31:0],    IMEM_DATA[31:0],    CNT_Stall[31:0],    PC_MW[31:0],
    DMEM_ADDR[31:0],    DMEM_DATA[31:0],    64'd0,

    PC_F_[31:0],        INST_F_[31:0],      CNT_Cycle[63:0],
    DBG_MEM150[31:0],   32'd0,              32'd0,
    {   8'd0, 8'd0, 8'd0, 8'd0
    }
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
//            if (COLT45_CONTROL) $monitor(" (%d) CTL DX %b", DBG_cycle, IControlDX_);
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
        $display("%d]  /MW : %h<=%h", DBG_cycle, MemAddrDX_, MemWValueDX_);
//        $display("%d]  /MW : %b", DBG_cycle, IControlDX_);
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
//        $display("%d]      : %b", DBG_cycle, IControl_MW); // Make a task to break into fields
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
            MemAddrDX_, MemAddrDX_, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddrDX_[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
    end
end endgenerate

generate if (COLT45_SCRATCH) begin:_SCRATCH_
    always@(posedge clk) if (!stall && _hot_DB) begin
        $display("\n=============");
        DUMP_PC();
        $display("TARG=%h WM=%b: IO=%b BR=%b IC=%b DC=%b IB=%b DB=%b",
            MemAddrDX_[31:28], _WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DC, _hot_IB, _hot_DB);
        if (|_WriteMask) begin
            regfile.DUMP();
            $display("[%h,%d] <<= %h(%d) {%b}",
                MemAddrDX_, MemAddrDX_, _WDataMasked, _WDataMasked, _WriteMask);
        end else begin
            $display("[%h,%d] ==> %h(%d)",
                MemAddrDX_, MemAddrDX_, RData_DB, RData_DB);
        end
        $display("=============\n");
    end
end endgenerate

// synthesis translate_on

`else //COLT45_KILLFUN (either def/ndef check)

assign trace = 1024'd0;

`endif //COLT45_KILLFUN (either def/ndef check)

endmodule
