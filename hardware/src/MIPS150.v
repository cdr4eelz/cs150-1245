`include "CPUGlobal.vh"

module MIPS150 #(
    parameter DD=`COLT45_DD,
    parameter ClockFreq=50_000_000,
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

// CP3+
`ifdef __COLT45_pre3
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
`endif

//BRK tap (will become internal instead)
    input brk,
    output [0:1023] trace,
    inout  [35: 0] SCOPE_CPU,

    input stall
);

// CP3+
`ifdef __COLT45_pre3
    assign bypass_addr=32'd0, bypass_din=32'd0, bypass_we=4'd0;
    assign filler_color=24'd0, filler_valid=1'b0, line_color=32'd0, line_point=10'd0;
    // Remove these for CP5. 
    assign line_color_valid = 1'b0;
    assign line_x0_valid = 1'b0;
    assign line_x1_valid = 1'b0;
    assign line_y0_valid = 1'b0;
    assign line_y1_valid = 1'b0;

    assign line_trigger=1'b0;
`endif

    // Global sorts of things
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun TUN_CPUGlobal // Drive CPUGlobal bus from CPU module inputs
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );


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

    // Forward declare feedback related wires (other key wires declared just prior to use)
    wire         #DD DOBranch_DX_WF_;
    wire [31: 0] #DD PCBranch_DX_WF_;
    wire [ 4: 0] #DD WBKReg_M_WF_;   // Not sure there really is a "W" stage anywhere!
    wire [31: 0] #DD WBKDat_M_WF_;   // but the concept seems harmless.
    wire         #DD WBKCanFWD_M_WF_;// This prevents accidental creation of a slow MDX stage!


    // Declare outputs of WF stage
    wire [31: 0] INST_ADDR, INST_DATA; //Data fetch is sync'd with StageWF
    wire [31: 0] StepCount, StallCount;
    StageWF #(
        .COUNTERWIDTH(32)//, .BOOTPC(32'h6_000_0000) //TODO: Change back to default/BIOS
    ) s_WF ( .CPUGlobal(CPUGlobal),
        .DOBranch(DOBranch_DX_WF_), .PCBranch(PCBranch_DX_WF_),
        .PC(INST_ADDR),
        .STEPCOUNT(StepCount), .STALLCOUNT(StallCount)
    );


    // Pipeline border: WF/DX
    wire [31: 0] PC_DX;
    wire [31: 0] INST_DX;
    PipelineRegister #( .Width(32) )
        REG_PC_DX   ( .CPUGlobal(CPUGlobal),  .In(INST_ADDR),   .Out(PC_DX) );
    PipelineRegister #( .Width(32), .LatchOnly(1) ) // Registered for us in prior stage
        REG_INST_DX ( .CPUGlobal(CPUGlobal),  .In(INST_DATA),   .Out(INST_DX) );
    //NOTE: INST_DATA gets changed early by BRAM (no disable availabe) but INST_DX gets "latched" on stall!

    // RegFile lines (write driven by write-back from M-stage, read driven asynchronously by DX-stage)
    wire [ 4: 0] REGFILE_ra1, REGFILE_ra2, REGFILE_wa;
    wire [31: 0] REGFILE_rd1, REGFILE_rd2, REGFILE_wd;
    assign REGFILE_wa = WBKReg_M_WF_, REGFILE_wd = WBKDat_M_WF_;
    wire REGFILE_we = ~stall && (REGFILE_wd != 0); // Mute "we" if "wd"==0 for signal clarity
    RegFile regfile
    ( .clk(clk),
        // Write is synchronous
        .we(REGFILE_we), .wa(REGFILE_wa), .wd(REGFILE_wd),
        // Read is asynchronous & always enabled (even during stall)
        .ra1(REGFILE_ra1), .rd1(REGFILE_rd1),
        .ra2(REGFILE_ra2), .rd2(REGFILE_rd2)
    );

    // Forwarding calculation
    wire FWD_Allow = WBKCanFWD_M_WF_; // Has already checked for "wa"==0 elsewhere
    wire FWD_1 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra1) : 1'b0;
    wire FWD_2 = (FWD_Allow) ? (REGFILE_wa == REGFILE_ra2) : 1'b0;
    wire [31: 0] #DD FWD_rd1 = (FWD_1) ? REGFILE_wd : REGFILE_rd1;
    wire [31: 0] #DD FWD_rd2 = (FWD_2) ? REGFILE_wd : REGFILE_rd2;

    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] MemAddrDX_, MemWValueDX_, RegWValueDX_;
    StageDX s_DX
    ( //.CPUGlobal(CPUGlobal),
        //Async regfile reads
        .REG_R1_(REGFILE_ra1), .REG_D1_(FWD_rd1),
        .REG_R2_(REGFILE_ra2), .REG_D2_(FWD_rd2),
        //Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Outputs
        .IControl_(IControlDX_),
        .MemAddr_(MemAddrDX_), .MemWValue_(MemWValueDX_),
        .RegWValue_(RegWValueDX_),
        //Feedbacks
        .DOBranch_(DOBranch_DX_WF_), .PCBranch_(PCBranch_DX_WF_)
    );

    // Pipeline border: DX/M
    `BUS_ICTL_type IControl_M, IControl__M;
    wire  [31: 0]   MemAddr__M, MemAddr_M;
    wire  [31: 0]   MemWValue__M, RegWValue_M;
    wire  [31: 0]   PC_M;
    PipelineRegister #( .Width(`BUS_ICTL_width) )   // Register all controls & let unused get pruned out
        REG_IControl_M  ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl_M  ) );
    PipelineRegister #( .Width(`BUS_ICTL_width), .LatchOnly(1) )
        REG_IControl__M ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl__M ) );
    PipelineRegister #( .Width(32), .LatchOnly(1) )
        REG_MemAddr__M  ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr__M  ) );
    PipelineRegister #( .Width(32) )
        REG_MemAddr_M   ( .CPUGlobal(CPUGlobal),    .In(MemAddrDX_  ),  .Out(MemAddr_M   ) );
    PipelineRegister #( .Width(32), .LatchOnly(1) )
        REG_MemWValue__M( .CPUGlobal(CPUGlobal),    .In(MemWValueDX_),  .Out(MemWValue__M) );
    PipelineRegister #( .Width(32) )
        REG_RegWValue_M ( .CPUGlobal(CPUGlobal),    .In(RegWValueDX_),  .Out(RegWValue_M ) );
    PipelineRegister #( .Width(32) ) //TODO: Use simple flag for "in-bios/allow-I-write"
        REG_PC_M        ( .CPUGlobal(CPUGlobal),    .In(PC_DX       ),  .Out(PC_M        ) );

    // MEMORY/IO Drives
    wire _hot_IO, _hot_BR, _hot_DC, _hot_IC, _hot_DB, _hot_IB;
    wire [ 3: 0] _WriteMask, _ByteMask;
    wire [31: 0] _WDataMasked;
    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB;
    StageM s_M
    ( //.CPUGlobal(CPUGlobal),
        //Inputs
        ._IControl  (IControl__M),  .IControl   (IControl_M),
        ._MemAddr   (MemAddr__M),   .MemAddr    (MemAddr_M),
        ._MemWValue (MemWValue__M), .RegWValue  (RegWValue_M),
        .PC         (PC_M),
        //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_), .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_),
        //Memory/IO patchwork
        ._hot_IO(_hot_IO), ._hot_BR(_hot_BR), ._hot_DC(_hot_DC),
        ._hot_IC(_hot_IC), ._hot_DB(_hot_DB), ._hot_IB(_hot_IB),
        ._WriteMask(_WriteMask), ._WDataMasked(_WDataMasked), ._ByteMask(_ByteMask),
        .RData_IO(RData_IO), .RData_BR(RData_BR), .RData_DC(RData_DC), .RData_DB(RData_DB)
    );

    // Instruction fetch selection
    wire INST_bios = (INST_ADDR[31:28] == 4'h4);
    wire [31:0] INST_BR, INST_IC;
    assign INST_DATA = (INST_bios) ? INST_BR : INST_IC;

    // MEMORY & IO ELEMENTS THEMSELVES

`ifndef COLT45_FUN //STRICT
    bios_mem brom_bios
    ( .clka(clk), .ena(~stall && _hot_BR),
        .addra(MemAddr__M[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/

    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
        .enb(INST_bios), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;
`else
    bios_mem brom_bios //Hack in external writeability for PLOP (32-bit wide, no byte mask)
    ( .clka(clk), .ena(~stall && _hot_BR),
        .addra(MemAddr__M[13:2]),
        .douta(RData_BR),//OUT-32
        .wea(1'b0), .dina(32'd0),
    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
        .enb(INST_bios), .doutb(INST_BR),
        .web(1'b0), .dinb(32'd0)
    ) /* synthesis syn_noprune=1 */;
`endif

    assign dcache_addr = MemAddr__M,
        dcache_we = (~stall && _hot_DC) ? (_WriteMask) : 4'b0000,
        dcache_din = _WDataMasked,
        dcache_re = (~stall && _hot_DC) ? (_WriteMask == 4'b0000) : 1'b0,
        RData_DC = dcache_dout;
//  assign dcache_addr=32'd0, dcache_we=4'b0000, dcache_re=1'b0, dcache_din=32'd0, RData_DC=32'd0;

//    assign icache_addr=INST_ADDR, // INST_ADDR/DATA_ADDR/NONE
 //       icache_we=4'b0000,
  //      icache_din=_WDataMasked,
   //     icache_re=1'b0,
    //    INST_IC=instruction;
    assign icache_addr=32'd0, icache_we=4'b0000, icache_re=1'b0, icache_din=32'd0, INST_IC=32'd0;

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
    // INSTRUCTION Fletch
      .clkb(clk), .addrb(INST_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB)
    ) /* synthesis syn_noprune=1 */;

    //TODO: Split MEMIOPlex into separate RX vs TX RVA's (parameter based?)
    `BUS_SHAKE_type(8) UATX, UARX;
    MEMIOPlex iomap_uart
    ( .clk(clk), .rst(rst), .ena(~stall && _hot_IO),
        .addra(MemAddr__M[13:2]),
        .douta(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
        .RVA_RX(UARX), .RVA_TX(UATX)
    );

    //TODO: Make this into UART wrapper that takes two RVA's
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


// Having constraint trouble when attempting ILA inclusion (some signals getting munched out???)
wire [1023:0] scoper = { // 4 segments of 8 values is 32 values (each 32-bit or 32-bit aligned)
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

    32'd0,              32'd0,              32'd0,              32'd0,
    32'd0,              32'd0,              32'd0,              32'd0
};
wire [31:0] trig0 = {FWD_1,2'b00,REGFILE_ra1, FWD_2,2'b00,REGFILE_ra2,
            REGFILE_we,FWD_Allow,1'b0,REGFILE_wa,
            _hot_IO,_hot_BR,_hot_IC,_hot_DC,_hot_IB,_hot_DB,~rst,stall};
cs_ila_1024 CS_ILA ( .CONTROL(SCOPE_CPU),  .CLK(clk),
    .DATA( scoper ),         // IN BUS [1023:0]
    .TRIG0( trig0 ),        // IN BUS [31:0]
    .TRIG1( PC_DX ),        // IN BUS [31:0]
    .TRIG2( INST_DX ),      // IN BUS [31:0]
    .TRIG3( StepCount )     // IN BUS [31:0]
) /* synthesis syn_noprune=1 */;





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
        $display("** TARG=%h W=%b: IO=%b BR=%b IC=%b DB=%b IB=%b",
            MemAddr__M[31:28], |_WriteMask, _hot_IO, _hot_BR, _hot_IC, _hot_DB, _hot_IB);
    end
end endgenerate

// synthesis translate_on

endmodule
