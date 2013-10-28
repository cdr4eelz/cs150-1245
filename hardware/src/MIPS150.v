`include "CPUBusses.vh"

module MIPS150 #(
    parameter ClockFreq=50_000_000
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

// CP3+
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
    output         line_trigger,

    input stall
);

// CP3+
    assign bypass_addr=32'd0, bypass_din=32'd0, bypass_we=4'd0;
    assign filler_color=24'd0, filler_valid=1'b0, line_color=32'd0, line_point=10'd0;
    // Remove these for CP5. 
    assign line_color_valid = 1'b0;
    assign line_x0_valid = 1'b0;
    assign line_x1_valid = 1'b0;
    assign line_y0_valid = 1'b0;
    assign line_y1_valid = 1'b0;

    assign line_trigger=1'b0;

    // Global sorts of things
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun TUN_CPUGlobal // Drive CPUGlobal bus from CPU module inputs
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    `BUS_MMAP_type IO2MMAP, BIOSROM, DACACHE, ITCACHE, DATBRAM, INSBRAM;
    wire [31:0] INST_ADDR, INST_DATA; //Global, but are sync'd with WF stage mostly

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
            REGFILE_we = 1'b1; //NOTE: The trick of write to reg#0 is used for non-write

    // Declare outputs of WF stage
    wire [31: 0] StepCount, StallCount;
    StageWF #(
        .COUNTERWIDTH(32), .BOOTPC(32'h2_000_0000)
    ) s_WF ( .CPUGlobal(CPUGlobal),
        .DOBranch(DOBranch_DX_WF_), .PCBranch(PCBranch_DX_WF_),
        .INST_ADDR(INST_ADDR), //OUT to prep during this cycle
        .STEPCOUNT(StepCount), .STALLCOUNT(StallCount)
    );

    // Pipeline border: WF/DX
    wire [31: 0] PC_DX, INST_DX;
    PipelineRegister #( .Width(32) )
        REG_PC_DX   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),    .Out(PC_DX) );
    PipelineRegister #( .Width(32), .PreRegistered(1) ) // Registered for us in prior stage
        REG_INST_DX ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),  .Out(INST_DX) );
    //NOTE: INST_DATA gets changed early by BRAM (no disable availabe) but INST_DX gets "latched" on stall!

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
    (//.CPUGlobal(CPUGlobal),
        .REG_R1_(REGFILE_ra1), .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2), .REG_D2_(FWD_rd2),
        //Inputs
        .PC(PC_DX), .INST(INST_DX),
        //Outputs
        .IControl_  (IControlDX_),
        .MemAddr_   (MemAddrDX_),   .MemWValue_ (MemWValueDX_),
        .RegWValue_ (RegWValueDX_), .PCPLUS8_   (PCPLUS8DX_),
        //Feedbacks
        .DOBranch_(DOBranch_DX_WF_), .PCBranch_(PCBranch_DX_WF_)
    );

    // Pipeline border: DX/M
    `BUS_ICTL_type IControl_M, IControl__M;
    wire  [31: 0]   MemAddr__M, MemAddr_M;
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
    (//.CPUGlobal  (CPUGlobal),
        .IO2MMAP(IO2MMAP), .BIOSROM(BIOSROM),
        .DACACHE(DACACHE), .ITCACHE(ITCACHE),
        .DATBRAM(DATBRAM), .INSBRAM(INSBRAM),
        //Inputs
        ._IControl  (IControl__M),  .IControl   (IControl_M),
        ._MemAddr   (MemAddr__M),   .MemAddr    (MemAddr_M),
        ._MemWValue (MemWValue__M), .RegWValue  (RegWValue_M),
        .PCPLUS8    (PCPLUS8_M),
        //Outputs
        //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_), .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_)
    );


    // Key components indirectly wired elsewhere:

    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .wa (REGFILE_wa), .wd(REGFILE_wd), .we(~stall && REGFILE_we),
        // Read is asynchronous & always enabled
        .ra1(REGFILE_ra1), .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2), .rd2(REGFILE_rd2)
    );

//TODO: Use PARAMETER for CP-LEVEL not #define
//TODO: Add an optional enable on the BUS_MMAP_tap which mutes both masks during the TAP!
//TODO: Add parameter to the TAP to perform address selection?
//TODO: Move memories into the MEMIOPLEX housing (or MEMIOPLEX becomes generic instantiator/tapper)

    wire INST_bios = (INST_ADDR[31:28] == 4'h4);
    wire [31:0] INST_BR, INST_IB;
    assign INST_DATA = (INST_bios) ? INST_BR : INST_IB;

    `BUS_SHAKE_type(8) UATX, UARX;
    MEMIOPlex iomap_uart
    ( .clk(clk), .rst(rst), .stall(stall),
        .IOMAP(IO2MMAP),
        .RVA_TX(UATX), .RVA_RX(UARX)
    );

    bios_mem brom_bios
    ( .clka(clk), .addra(`MMAP_Addr(BIOSROM)),
        .ena(~stall && |(/*`MMAP_WMask(BIOSROM) |*/ `MMAP_RMask(BIOSROM))),
        .douta(`MMAP_RData(BIOSROM)),//OUT-32
      /*.wea(`MMAP_WMask(BIOSROM)), .dina(`MMAP_WData(BIOSROM)),*/
    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
        .enb(INST_bios), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0; // dcache_dout
assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0; // INST_IC=instruction
/* icache_addr=(INST_ADDR/DATA_ADDR/NONE) */

    dmem_blk_ram bram_dmem
    ( .clka(clk), .addra(`MMAP_Addr(DATBRAM)),
        .ena(~stall && |(`MMAP_WMask(DATBRAM) | `MMAP_RMask(DATBRAM))),
        .douta(`MMAP_RData(DATBRAM)),//OUT-32
        .wea(`MMAP_WMask(DATBRAM)), .dina(`MMAP_WData(DATBRAM))
    ) /* synthesis syn_noprune=1 */;

    imem_blk_ram bram_imem
    ( .clka(clk), .addra(`MMAP_Addr(INSBRAM)),
        .ena(~stall && |(`MMAP_WMask(INSBRAM) /*| `MMAP_RMask(INSBRAM)*/)),
      /*.douta(`MMAP_RData(INSBRAM)),//OUT-32*/
        .wea(`MMAP_WMask(INSBRAM)), .dina(`MMAP_WData(INSBRAM)),
    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB) // inst fletch
    ) /* synthesis syn_noprune=1 */;


    UART #(.ClockFreq(ClockFreq)) uart
    ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        // Transmitter  (handshakes go both in/out)
        .DataIn(        `SHAKE_Data(        8,UATX)),
        .DataInValid(   `SHAKE_DataValid(   8,UATX)),
        .DataInReady(   `SHAKE_DataReady(   8,UATX)),
        // Receiver     (handshakes go both in/out)
        .DataOut(       `SHAKE_Data(        8,UARX)),
        .DataOutValid(  `SHAKE_DataValid(   8,UARX)),
        .DataOutReady(  `SHAKE_DataReady(   8,UARX))
    );


`ifdef COLT45_DBG
// synthesis translate_off

    reg[8:0] DBG_cycle, DBG_step;
    initial begin
        $display ("%m");
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

    always@(rst, stall) begin
        $display("=================================================================");
        $display("CTL-: C %h  R %h  S %h", clk, rst, stall);
        $strobe ("CTL+: C %h  R %h  S %h", clk, rst, stall);
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

        $display("%d]   /DX: %h %h", DBG_cycle, INST_ADDR, INST_DATA);
        $display("%d]  /M  : %h<=%h", DBG_cycle, MemAddr__M, MemWValue__M);
        $display("%d]  /M  : %b", DBG_cycle, IControl__M);
        $display("%d] /WF : R[%h,%d]<=%h(%d)", DBG_cycle, WBKReg_M_WF_, WBKReg_M_WF_,
                            WBKDat_M_WF_, WBKDat_M_WF_);

        DBG_cycle = DBG_cycle + 1;
        if (!stall) DBG_step = DBG_step + 1;
        if (DBG_step > (48)) DO_FINISH();
        #1;

        $display("%d]/= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =\\", DBG_cycle);
        $display("%d] RST: %d   STL: %d   STEP: %d", DBG_cycle, rst, stall, DBG_step);
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
        if (`MMAP_WMask(IO2MMAP) != 0) begin
            $display("** IO2MMAP[%h,%d] <= %h(%d) {%b}", `MMAP_Addr(IO2MMAP), `MMAP_Addr(IO2MMAP),
            `MMAP_WData(IO2MMAP), `MMAP_WData(IO2MMAP), `MMAP_WMask(IO2MMAP));
        end
        if (`MMAP_WMask(ITCACHE) != 0) begin
            $display("** ITCACHE[%h,%d] <= %h(%d) {%b}", `MMAP_Addr(ITCACHE), `MMAP_Addr(ITCACHE),
            `MMAP_WData(ITCACHE), `MMAP_WData(ITCACHE), `MMAP_WMask(ITCACHE));
        end
        if (`MMAP_WMask(DACACHE) != 0) begin
            $display("** DACACHE[%h,%d] <= %h(%d) {%b}", `MMAP_Addr(DACACHE), `MMAP_Addr(DACACHE),
            `MMAP_WData(DACACHE), `MMAP_WData(DACACHE), `MMAP_WMask(DACACHE));
        end
        if (`MMAP_WMask(INSBRAM) != 0) begin
            $display("** INSBRAM[%h,%d] <= %h(%d) {%b}", `MMAP_Addr(INSBRAM), `MMAP_Addr(INSBRAM),
            `MMAP_WData(INSBRAM), `MMAP_WData(INSBRAM), `MMAP_WMask(INSBRAM));
        end
        if (`MMAP_WMask(DATBRAM) != 0) begin
            $display("** DATBRAM[%h,%d] <= %h(%d) {%b}", `MMAP_Addr(DATBRAM), `MMAP_Addr(DATBRAM),
            `MMAP_WData(DATBRAM), `MMAP_WData(DATBRAM), `MMAP_WMask(DATBRAM));
        end
    end
// synthesis translate_on
`endif //COLT45_DBG

endmodule
