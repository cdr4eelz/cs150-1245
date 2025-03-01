`include "../cpuglobal.vh"

module CPUMIPS #(
    parameter PC_BOOT=32'h4000_0000, PC_ISR=32'hC000_0180,
    parameter DD=`COLT45_DD,
    parameter COLT45_SCOPE=0, COLT45_BRK=0,
    parameter COLT45_PC=0, COLT45_REGREAD=0, COLT45_CONTROL=0, COLT45_STEPMAX=0 //48
)(
    input  clk, rst, stall,

// Regfile lines
    output          REGFILE_we,
    output [31: 0]  REGFILE_wd,
    output [ 4: 0]  REGFILE_ra1, REGFILE_ra2, REGFILE_wa,
    input  [31: 0]  REGFILE_rd1, REGFILE_rd2,

// COP0 lines
    output          COP0_we,
    output [31: 0]  COP0_wd,
    output [ 4: 0]  COP0_ra,
    input  [31: 0]  COP0_rd,
    output [31: 0]  intr_pc,
    output          intr_handled,
    input           intr_request,

// Memory lines
    output [31: 0]  IMEM_ADDR, DMEM_ADDR,
    input  [31: 0]  IMEM_DATA, DMEM_DATA,
    output          MemToRegDX_, MemWriteDX_, PCinBIOSDX_,
    output [31: 0]  _WDataMasked,
    output [ 3: 0]  _WriteMask

);

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

    // Declare outputs of F stage
    wire [31: 0] PC_F_, PCNEXT_F_;
    wire [31: 0] INST_F_;
    wire [31: 0] CNT_Stall, CNT_BRANCH, CNT_ISR, CNT_Cycle, CNT_Inst;
    wire WAS_Running, WAS_Stall, WAS_Inst, WAS_Branch, WAS_ISR;
    wire INST_CouldBranch_F_, DO_ISR;
    StageF #(
        .PC_ISR(PC_ISR), .PC_BOOT(PC_BOOT),
        .COUNTERWIDTH(32)
    ) s_F ( .clk(clk), .rst(rst), .stall(stall),
        //Inputs (feedback from other stages)
        ._DoBranch(BRA_DoBranch_DX2F_), ._PCBranch(BRA_PCBranch_DX2F_),
        ._ResetCounters(1'b0), //CNT_Reset_MW2F_
        ._DoISR(DO_ISR),
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
    //TODO: Pass preview to next stage (or move decode to be with Fetch)
    InstructionPreview previewFetch(
        ._inst(INST_F_), .couldBranch(INST_CouldBranch_F_)
    );
//  assign DO_ISR = {BRA_IRQPending_DX2F_,stall,INST_CouldBranch_F_,WAS_Branch,WAS_ISR} == 5'b10000;
    assign DO_ISR = BRA_IRQPending_DX2F_ && ~|{stall,INST_CouldBranch_F_,WAS_Branch,WAS_ISR};


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
    assign REGFILE_wa = WBK_Reg_MW2DX_, REGFILE_wd = WBK_Val_MW2DX_;
    assign REGFILE_we = !stall && (REGFILE_wa != 0); // Mute "we" if "wa"==0 for signal clarity */
    // FORWARDING calculation
    wire FWD_Allow = (REGFILE_wa != 0) ? WBK_CanFWD_MW2DX_ : 1'b0;
    wire FWD_1 = FWD_Allow && (REGFILE_wa == REGFILE_ra1);
    wire FWD_2 = FWD_Allow && (REGFILE_wa == REGFILE_ra2);
    wire [31: 0] #DD FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] #DD FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // Declare outputs of DX stage
    wire [31: 0] MemAddrDX_, RegWValueDX_, MemWValueDX_;
    wire [ 4: 0] DestRegDX_;
    wire [ 1: 0] MemShiftDX_;
    wire         COPWriteDX_;
//  wire         MemToRegDX_, MemWriteDX_;

    // COPROCESSOR async-read via DX-stage (like REGFILE) but sync-write from REGFORWARD
    assign COP0_we = !stall && COPWriteDX_;
    assign COP0_wd = FWD_rd2;
    assign intr_pc = PCNEXT_F_;
    assign intr_handled = !stall && WAS_ISR;
    assign BRA_IRQPending_DX2F_ = intr_request;

    StageDX s_DX
    ( //NOTE: Currently combinational: .clk(clk), .rst(rst), .stall(stall),
        //Async REGFILE/COP0 reads
        .REG_R1_(REGFILE_ra1),  .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2),  .REG_D2_(FWD_rd2),
        .COP0_R_(COP0_ra),      .COP0_D_(COP0_rd),
        //Stage Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Global control signals
        .COPWrite_(COPWriteDX_), //COP0 write (mtc0), this cycle!
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
    wire  [31: 0]   MemAddr_MW; //NOTE:Only uses low two bits! (Rest for debug)
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
    PipelineRegister #( .Width(32) )
        PIPR_PC_MW        ( .clk(clk), .rst(1'b0), .stall(stall),
                            .In(PC_DX       ),  .Out(PC_MW        ) );
//=============<<< PIPELINE-BORDER: DX/M |===============

    assign DMEM_ADDR    = MemAddrDX_;
    assign PCinBIOSDX_  = (PC_DX[31:28]==4'b0100); //NOTE:Approximate by borrowing from other stage!

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

//=============DEBUGGING TOOLS BELOW THIS POINT=============
`ifndef COLT45_KILLFUN //Mostly to trigger text editor to hide this whole mess!

//Shared between BRK and SCOPE

wire [31:0] keywatch = {
    REGFILE_we,REGFILE_wa[4:0],REGFILE_ra2[4:0], REGFILE_ra1[4:0],
    FWD_Allow,FWD_2,FWD_1,32'd0,//DBG_MEM150[31]
        4'b0000, //_hot_IO,_hot_BR,_hot_IC,_hot_DC,
        4'b0000, //hoti_[3:0],
        rst,BRA_IRQPending_DX2F_,BRA_DoBranch_DX2F_,stall
};

assign trace = {
// 3 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
    // 0 \\             // 1 \\             // 2 \\             // 3 \\
    PC_DX[31:0],        INST_DX[31:0],      CNT_Inst[31:0],     BRA_PCBranch_DX2F_[31:0],
    REGFILE_wd[31:0],   FWD_rd2[31:0],      FWD_rd1[31:0],      keywatch[31:0],

    128'd0, //RData_IO[31:0],     RData_BR[31:0],     RData_DC[31:0],     RData_DB[31:0],
    MemAddr_MW[31:0],   MemAddrDX_[31:0],   _WDataMasked[31:0],
    {   8'b00000000, //_hot_IO,_hot_BR,_hot_IC,_hot_DC, 1'b0,_hot_ISR,_hot_IB,_hot_DB,
        8'd0, //dcache_we, 3'd0,dcache_re,
        8'd0, //icache_we, 3'd0,icache_re,
        _WriteMask, WAS_ISR,WAS_Stall,WAS_Inst,WAS_Branch
    },

    IMEM_ADDR[31:0],    IMEM_DATA[31:0],    CNT_Stall[31:0],    PC_MW[31:0],
    DMEM_ADDR[31:0],    DMEM_DATA[31:0],    COP0_rd[31:0],
    {   8'd0, 8'd0,
        DO_ISR,COPWriteDX_,2'b00, !INST_CouldBranch_F_,!stall,!WAS_Branch,!WAS_ISR,
        3'd0, COP0_ra[4:0]
    },

    PC_F_[31:0],        INST_F_[31:0],      CNT_Cycle[31:0],    32'd0,
    32'd0/*DBG_MEM150[31:0]*/,   CNT_BRANCH[31:0],   CNT_ISR[31:0],
    32'd0 //graphics_status
};


generate if (COLT45_BRK) begin:_BRK_
    //TODO: Move from top to here
end endgenerate //COLT45_BRK


generate if (COLT45_SCOPE) begin:_SCOPE_MIPSY_
    wire [31:0] CS_TRIG0 = keywatch[31:0];
    wire [31:0] CS_TRIG1 = PC_DX[31:0];
    wire [31:0] CS_TRIG2 = INST_DX[31:0];
    wire [31:0] CS_TRIG3 = CNT_Inst[31:0];

    wire [35:0] cs_icon_scope;
    cs_icon_1 CS_ICON_MIPSY (
        .CONTROL0(cs_icon_scope) // INOUT BUS [35:0]
    ) /* synthesis syn_noprune=1 */;

    cs_ila_1024 CS_ILA_MIPSY ( .CONTROL(cs_icon_scope),
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

// synthesis translate_on

`else //COLT45_KILLFUN (either def/ndef check)

assign trace = 1024'd0;

`endif //COLT45_KILLFUN (either def/ndef check)

endmodule
