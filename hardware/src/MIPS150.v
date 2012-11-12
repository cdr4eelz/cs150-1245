`include "CPUBusses.vh"

`timescale 1ns/1ps

module MIPS150 (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX
);
    wire stl = stall;   // Just rename so it matches nicely internal to CPU
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_MEMIO_type         MemoryIO;
    `BUS_ShakeRx_type(8)    UARX;
    `BUS_ShakeTx_type(8)    UATX;
    
    // Register & Memory busses
    wire [ 4: 0] REG_ra1, REG_ra2, REG_wa;
    wire [31: 0] REG_rd1, REG_rd2, REG_wd;
    wire REG_we;
    
    wire [11: 0]    IMEM_addra, IMEM_addrb,     DMEM_addra;
    wire [31: 0]    IMEM_dina,  IMEM_doutb,     DMEM_douta, DMEM_dina;
    wire [ 3: 0]    IMEM_wea,                   DMEM_wea;
    
    /* Naming conventions (might be inconsistent/in-flux though :)
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
    */
    
    // Forward declare wires to explicitly feedback to prior stages
    wire         #1 DOBranch_DX_WF_;
    wire [31: 0] #1 PCBranch_DX_WF_;
    wire [ 4: 0] #1 WBKReg_M_WF_;   // Not sure there really is a "W" stage anywhere!
    wire [31: 0] #1 WBKDat_M_WF_;   // but the concept seems harmless.
    wire         #1 WBKCanFWD_M_WF_;// This prevents accidental creation of a slow MDX stage!
    
    assign REG_wa = WBKReg_M_WF_,   REG_wd = WBKDat_M_WF_,  REG_we = !stl;
    
    // Declare outputs of WF stage
    wire [31: 0] PC_WF_, INST_WF_;
    wire [15: 0] StepCount, StallCount;
    StageWF s_WF    // WF STAGE itself
    (   .CPUGlobal(CPUGlobal), .STEPCOUNT(StepCount), .STALLCOUNT(StallCount),
        .IMEM_read_addr (IMEM_addrb),   .IMEM_read_data(IMEM_doutb),
    //Inputs
        .DOBranch       (DOBranch_DX_WF_),
        .PCBranch       (PCBranch_DX_WF_),
    //Outputs
        .PC             (PC_WF_),       .INST       (INST_WF_)
    );
    
    // Pipeline border: WF/DX
    wire [31: 0] PC_DX, INST_DX;
    PipelineRegister #( .Width(32)
        ) REG_PC_DX         ( .CPUGlobal(CPUGlobal),    .In(PC_WF_),        .Out(PC_DX) );
    PipelineRegister #( .Width(32), .PreRegistered(1)   // Registered for us in prior stage
        ) REG_INST_DX       ( .CPUGlobal(CPUGlobal),    .In(INST_WF_),      .Out(INST_DX) );
    
    // Mini-forwarding calculation
    wire FWD_Allow = WBKCanFWD_M_WF_;
    wire FWD_1 = (FWD_Allow && (REG_wa==REG_ra1));
    wire FWD_2 = (FWD_Allow && (REG_wa==REG_ra2));
    wire [31: 0] FWD_rd1 = (FWD_1) ? REG_wd : REG_rd1;
    wire [31: 0] FWD_rd2 = (FWD_2) ? REG_wd : REG_rd2;
    
    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] MemAddrDX_, MemWValueDX_, RegWValueDX_, PCPLUS8DX_;
    StageDX s_DX
    ( .CPUGlobal(CPUGlobal),
        .REG_R1_    (REG_ra1),          .REG_R2_    (REG_ra2),
        .REG_D1_    (FWD_rd1),          .REG_D2_    (FWD_rd2),
    //Inputs
        .PC         (PC_DX),            .INST       (INST_DX),
    //Outputs
        .IControl_  (IControlDX_),
        .MemAddr_   (MemAddrDX_),
        .MemWValue_ (MemWValueDX_),
        .RegWValue_ (RegWValueDX_),
        .PCPLUS8_   (PCPLUS8DX_),
    //Feedbacks
        .DOBranch_  (DOBranch_DX_WF_),  // Feedback to WF stage
        .PCBranch_  (PCBranch_DX_WF_)   // Feedback to WF stage
    );
    
    // Pipeline border: DX/M
    `BUS_ICTL_type IControl_M, IControl__M;
    wire  [31: 0] MemAddr__M;
    wire  [31: 0] MemWValue__M, RegWValue_M;
    wire  [31: 0] PCPLUS8_M;
    PipelineRegister #( .Width(`BUS_ICTL_width) // Register all controls & let unused get pruned out
        ) REG_IControl_M    ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl_M  ) );
    PipelineRegister #( .Width(`BUS_ICTL_width), .PreRegistered(1) // Really, it's post-registered!
        ) REG_IControl__M   ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl__M ) );
    PipelineRegister #( .Width(32), .PreRegistered(1)
        ) REG_MemAddr__M    ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr__M  ) );
    PipelineRegister #( .Width(32), .PreRegistered(1)
        ) REG_MemWValue__M  ( .CPUGlobal(CPUGlobal),    .In(MemWValueDX_),  .Out(MemWValue__M) );
    PipelineRegister #( .Width(32)
        ) REG_RegWValue_M   ( .CPUGlobal(CPUGlobal),    .In(RegWValueDX_),  .Out(RegWValue_M ) );
    PipelineRegister #( .Width(32)
        ) REG_PCPLUS8_M     ( .CPUGlobal(CPUGlobal),    .In(PCPLUS8DX_ ),   .Out(PCPLUS8_M   ) );
    
    StageM  s_M
    (   .CPUGlobal  (CPUGlobal),
        .MemoryIO   (MemoryIO),
    //Inputs
        .IControl   (IControl_M),
        ._IControl  (IControl__M),
        ._MemAddr   (MemAddr__M),
        ._MemWValue (MemWValue__M),
        .RegWValue  (RegWValue_M),
        .PCPLUS8    (PCPLUS8_M),
    //Outputs
    //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_),     .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_)
    );
    
    // Temporarily plugged directly into DMEM & IMEM
    BUS_MEMIO_tap BUS_MEMIO_D
    ( ._BUS_(MemoryIO),
        .Addr(DMEM_addra),  .TMask(),
        .BMask(DMEM_wea),   .WData(DMEM_dina),
        .RData(DMEM_douta)
    );
    assign IMEM_addra=DMEM_addra, IMEM_wea=DMEM_wea, IMEM_dina=DMEM_dina;
    
    // Key components indirectly wired elsewhere
    
    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .wa(REG_wa),    .wd(REG_wd),    .we(REG_we),
        // Read is asynchronous
        .ra1(REG_ra1),  .ra2(REG_ra2),
        .rd1(REG_rd1),  .rd2(REG_rd2)
    );
    
    dmem_blk_ram DMEM
    (   .clka(clk),             // Clocks of a feather
        .ena    (1'b1),         .addra  (DMEM_addra),   // One DMEM port...
        .douta  (DMEM_douta),                           //  for data read...
        .dina   (DMEM_dina),    .wea    (DMEM_wea)      //  & data write
    );
    
    imem_blk_ram IMEM
    (   .clka(clk), .clkb(clk), // Clocks of a feather
        .ena    (1'b1),         .addra  (IMEM_addra),   // Separate IMEM port...
        .dina   (IMEM_dina),    .wea    (IMEM_wea),     //  for inst write...
                                                        // ...VS...
        .addrb  (IMEM_addrb),   .doutb  (IMEM_doutb)    //  inst fletch
    );
    
    UART uart
    (   .Clock(clk), .Reset(rst),  // Clocks of a feather
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        // Transmitter  (handshakes go both in/out)
        .DataIn(        `ShakeTx_DataIn(        8,UATX)),
        .DataInValid(   `ShakeTx_DataInValid(   8,UATX)),
        .DataInReady(   `ShakeTx_DataInReady(   8,UATX)),
        // Receiver     (handshakes go both in/out)
        .DataOut(       `ShakeRx_DataOut(       8,UARX)),
        .DataOutValid(  `ShakeRx_DataOutValid(  8,UARX)),
        .DataOutReady(  `ShakeRx_DataOutReady(  8,UARX))
    );
    
    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
    
// synthesis translate_off

    reg[8:0] DBG_cycle, DBG_step;
    initial begin
        $display ("-   -   -   -   -   -   -   -   -   -   -   -");
    end
    
    task DO_FINISH;
        begin
            $display("Ran %d / %d", DBG_cycle, DBG_step);
            $display("");
            regfile.DUMP();
            $finish();
        end
    endtask
    
    always@(rst, stl) begin
        $display("=================================================================");
        $display("CTL-: C %h  R %h  S %h", clk, rst, stl);
        $strobe ("CTL+: C %h  R %h  S %h", clk, rst, stl);
        $strobe ("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
        if (rst) begin
            DBG_cycle = 'bz;  DBG_step = 'bz;
        end else if (DBG_cycle[0] === 1'bz) begin
            DBG_cycle = 0;  DBG_step = 0;
        end
    end
    
    always@(posedge clk) if (DBG_cycle >= 0) begin:DBG_RUN_POS
        $display(" REG1:R(%h,%d)=%h(%d)", REG_ra1, REG_ra1, REG_rd1, REG_rd1);
        if (FWD_1) $display(" *FWD1:      >>%h(%d)", FWD_rd1, FWD_rd1);
        $display(" REG2:R(%h,%d)=%h(%d)", REG_ra2, REG_ra2, REG_rd2, REG_rd2);
        if (FWD_2) $display(" *FWD2:      >>%h(%d)", FWD_rd2, FWD_rd2);
        
        $display("%d]   /DX: %h %h", DBG_cycle, PC_WF_, INST_WF_);
        $display("%d]  /M  : %h<=%h", DBG_cycle, MemAddr__M, MemWValue__M);
        $display("%d]  /M  : %b", DBG_cycle, IControl__M);
        $display("%d] /WF : R[%h,%d]<=%h(%d)", DBG_cycle, WBKReg_M_WF_, WBKReg_M_WF_, 
                                                WBKDat_M_WF_, WBKDat_M_WF_);
        
        DBG_cycle = DBG_cycle + 1;
        if (!stl) DBG_step = DBG_step + 1;
        if (DBG_step > (48)) DO_FINISH();
        #1;
        
        $display("%d]/= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\", DBG_cycle);
        $display("%d] RST: %d   STL: %d   STEP: %d", DBG_cycle, rst, stl, DBG_step);
        // DOBranch_DX_WF_
        $display("%d]   /WF: %h *%d", DBG_cycle, PCBranch_DX_WF_, DOBranch_DX_WF_);
        $display("%d] WF/DX: %h %h #%d", DBG_cycle, PC_DX, INST_DX, StepCount);
        $display("%d] DX/M : %h <=%h", DBG_cycle, PCPLUS8_M-8, RegWValue_M);
        $display("%d]      : %b", DBG_cycle, IControl_M); // Make a task to break into fields
        $strobe ("%d] -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -", DBG_cycle);
    end
    
/*    always@* begin
        $display(" (%d) CTL DX %b", DBG_cycle, IControlDX_);
    end
    always@* begin
        if (REG_ra1 >= 0) begin
            $display(" reg1:%d R1(%h,%d)=%h (%d)", FWD_1, REG_ra1, REG_ra1, REG_rd1, REG_rd1);
        end
    end
    always@* begin
        if (REG_ra2 >= 0) begin
            $display(" reg2:%d R2(%h,%d)=%h (%d)", FWD_2, REG_ra2, REG_ra2, REG_rd2, REG_rd2);
        end
    end
*/
    
    always@(posedge clk) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        if (IMEM_wea != 0) begin
            $display("** I-MEM[%h,%d] <= %h(%d) {%b}", IMEM_addra*4, IMEM_addra*4, 
                    IMEM_dina, IMEM_dina, IMEM_wea);
        end
        if (DMEM_wea != 0) begin
            $display("** D-MEM[%h,%d] <= %h(%d) {%b}", DMEM_addra*4, DMEM_addra*4, 
                    DMEM_dina, DMEM_dina, DMEM_wea);
        end
        
        if (`MEMIO_TMask(MemoryIO) != 0) begin
            $display("* MEM[%h,%d] == %h(%d) {%b}", `MEMIO_Addr(MemoryIO), `MEMIO_Addr(MemoryIO), 
                    `MEMIO_RData(MemoryIO), `MEMIO_RData(MemoryIO), `MEMIO_TMask(MemoryIO));
        end
    end
    
// synthesis translate_on
    
endmodule
