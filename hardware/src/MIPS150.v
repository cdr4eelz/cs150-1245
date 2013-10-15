`include "CPUBusses.vh"

`timescale 1ns/1ps

module MIPS150(
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,

    // Memory system ports
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

    output [31:0] bypass_addr,
    output [31:0] bypass_din,
    output [3:0]  bypass_we,

    // Graphics ports
    input          filler_ready,
    input          line_ready,
    output  [23:0] filler_color,
    output         filler_valid,
    output  [31:0] line_color,
    output  [9:0]  line_point,
    output         line_color_valid,
    output         line_x0_valid,
    output         line_y0_valid,
    output         line_x1_valid,
    output         line_y1_valid,
    output         line_trigger
);

`ifndef COLT45_pre2
`ifndef COLT45_pre3
    // Remove these for CP5. 
    assign line_color_valid = 0;
    assign line_x0_valid = 0;
    assign line_x1_valid = 0;
    assign line_y0_valid = 0;
    assign line_y1_valid = 0;
`endif // !COLT45_pre3
`endif // !COLT45_pre2

// endmodule

    wire stl = stall;   // Just rename so it matches nicely internal to CPU
    `BUS_CPUGlobal_type CPUGlobal; //TODO: Eliminate CPUGlobal since it hides too much about usage
    `BUS_MEMIO_type     DMEM, IMEM, IOMAP;
    wire    [11: 0]     IMEM_addrb;
    wire    [31: 0]     IMEM_doutb;

    // Register lines
    wire    [ 4: 0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
    wire    [31: 0] REGFILE_rd1, REGFILE_rd2, REGFILE_wd;
    wire            REGFILE_we;

/*  Naming conventions (might be inconsistent/in-flux though :)
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

    assign REGFILE_wa = WBKReg_M_WF_,
            REGFILE_wd = WBKDat_M_WF_,
            REGFILE_we = ~stl; // Avoid premature or double writes during stall

    // Declare outputs of WF stage
    wire [31: 0] PC_WF_, INST_WF_;
    wire [15: 0] StepCount, StallCount; // TODO: How big do these need to be???
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
    PipelineRegister #( .Width(32) )
        REG_PC_DX   ( .CPUGlobal(CPUGlobal),  .In(PC_WF_),    .Out(PC_DX) );
    PipelineRegister #( .Width(32), .PreRegistered(1) ) // Registered for us in prior stage
        REG_INST_DX ( .CPUGlobal(CPUGlobal),  .In(INST_WF_),  .Out(INST_DX) );

    // Mini-forwarding calculation
    wire FWD_Allow = WBKCanFWD_M_WF_;
    wire FWD_1 = (FWD_Allow && (REGFILE_wa==REGFILE_ra1));
    wire FWD_2 = (FWD_Allow && (REGFILE_wa==REGFILE_ra2));
    wire [31: 0] FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] MemAddrDX_, MemWValueDX_, RegWValueDX_, PCPLUS8DX_;
    StageDX s_DX
    (// .CPUGlobal(CPUGlobal),
        .REG_R1_    (REGFILE_ra1),      .REG_R2_    (REGFILE_ra2),
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
    `BUS_ICTL_type  IControl_M,   IControl__M;
    wire  [31: 0]   MemAddr__M,   MemAddr_M;
    wire  [31: 0]   MemWValue__M, RegWValue_M;
    wire  [31: 0]   PCPLUS8_M;
    PipelineRegister #( .Width(`BUS_ICTL_width) )   // Register all controls & let unused get pruned out
        REG_IControl_M  ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl_M  ) );
    PipelineRegister #( .Width(`BUS_ICTL_width), .PreRegistered(1) )    // Really, it's post-registered!
        REG_IControl__M ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl__M ) );
    PipelineRegister #( .Width(32), .PreRegistered(1) )
        REG_MemAddr__M  ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr__M  ) );
    PipelineRegister #( .Width(32) )
        REG_MemAddr_M   ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr_M   ) );
    PipelineRegister #( .Width(32), .PreRegistered(1) )
        REG_MemWValue__M( .CPUGlobal(CPUGlobal),    .In(MemWValueDX_),  .Out(MemWValue__M) );
    PipelineRegister #( .Width(32) )
        REG_RegWValue_M ( .CPUGlobal(CPUGlobal),    .In(RegWValueDX_),  .Out(RegWValue_M ) );
    PipelineRegister #( .Width(32) )
        REG_PCPLUS8_M   ( .CPUGlobal(CPUGlobal),    .In(PCPLUS8DX_  ),  .Out(PCPLUS8_M   ) );

    StageM s_M
    (// .CPUGlobal  (CPUGlobal),
        .DMEM       (DMEM),             .IMEM(IMEM),
        .IOMAP      (IOMAP),
        //Inputs
        ._IControl  (IControl__M),      .IControl   (IControl_M),
        ._MemAddr   (MemAddr__M),       .MemAddr    (MemAddr_M),
        ._MemWValue (MemWValue__M),
        .RegWValue  (RegWValue_M),
        .PCPLUS8    (PCPLUS8_M),
        //Outputs
        //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_),     .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_)
    );


    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    (   ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );


    // Key components indirectly wired elsewhere

    RegFile regfile
    (   .clk(clk),
        // Write is synchronous
        .wa(REGFILE_wa),    .wd(REGFILE_wd),    .we(REGFILE_we),
        // Read is asynchronous
        .ra1(REGFILE_ra1),  .ra2(REGFILE_ra2),
        .rd1(REGFILE_rd1),  .rd2(REGFILE_rd2)
    );

    dmem_blk_ram bram_dmem
    (   .clka(clk), .ena( |`MEMIO_WMask(DMEM) || |`MEMIO_RMask(DMEM)),
        .addra  (`MEMIO_Addr(   DMEM)),     .douta  (`MEMIO_RData(  DMEM)),
        .wea    (`MEMIO_WMask(  DMEM)),     .dina   (`MEMIO_WData(  DMEM))
    );

    imem_blk_ram bram_imem
    (   .clka(clk), .ena( |`MEMIO_WMask(IMEM) /*|| |`MEMIO_RMask(IMEM)*/ ),
        .addra  (`MEMIO_Addr(   IMEM)),     /*.douta  (`MEMIO_RData(  IMEM)),*/
        .wea    (`MEMIO_WMask(  IMEM)),     .dina   (`MEMIO_WData(  IMEM)),

        .clkb(clk), //enb(1'b1)
        .addrb  (IMEM_addrb),   .doutb  (IMEM_doutb)    //  inst fletch
    );

    MEMIOPlex iomap_uart
    (   .CPUGlobal(CPUGlobal),
        .SERIAL_RX(FPGA_SERIAL_RX), .SERIAL_TX(FPGA_SERIAL_TX),
        .IOMAP(IOMAP)
    );


`ifdef COLT45_DBG
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
        $display(" REG1:R(%h,%d)=%h(%d)", REGFILE_ra1, REGFILE_ra1, REGFILE_rd1, REGFILE_rd1);
        if (FWD_1) $display(" *FWD1:      >>%h(%d)", FWD_rd1, FWD_rd1);
        $display(" REG2:R(%h,%d)=%h(%d)", REGFILE_ra2, REGFILE_ra2, REGFILE_rd2, REGFILE_rd2);
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

    /*
    always@* begin
        $display(" (%d) CTL DX %b", DBG_cycle, IControlDX_);
    end
    always@* begin
        if (REGFILE_ra1 >= 0) begin
        $display(" reg1:%d R1(%h,%d)=%h (%d)", FWD_1, REGFILE_ra1, REGFILE_ra1, REGFILE_rd1, REGFILE_rd1);
        end
    end
    always@* begin
        if (REGFILE_ra2 >= 0) begin
        $display(" reg2:%d R2(%h,%d)=%h (%d)", FWD_2, REGFILE_ra2, REGFILE_ra2, REGFILE_rd2, REGFILE_rd2);
        end
    end
    */

    always@(posedge clk) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        if (`MEMIO_WMask(IMEM) != 0) begin
            $display("** I-MEM[%h,%d] <= %h(%d) {%b}", `MEMIO_Addr(IMEM), `MEMIO_Addr(IMEM),
            `MEMIO_WData(IMEM), `MEMIO_WData(IMEM), `MEMIO_WMask(IMEM));
        end
        if (`MEMIO_WMask(DMEM) != 0) begin
            $display("** D-MEM[%h,%d] <= %h(%d) {%b}", `MEMIO_Addr(DMEM), `MEMIO_Addr(DMEM),
            `MEMIO_WData(DMEM), `MEMIO_WData(DMEM), `MEMIO_WMask(DMEM));
        end
        if (`MEMIO_WMask(IOMAP) != 0) begin
            $display("** IOMAP[%h,%d] <= %h(%d) {%b}", `MEMIO_Addr(IOMAP), `MEMIO_Addr(IOMAP),
            `MEMIO_WData(IOMAP), `MEMIO_WData(IOMAP), `MEMIO_WMask(IOMAP));
        end
    end
// synthesis translate_on
`endif //COLT45_DBG

endmodule
