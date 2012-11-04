`include "CPUBusses.vh"

`timescale 1ns/1ps

module MIPS150 (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX
);
    wire stl = stall;   // Just rename so it matches nicely internal to CPU
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_ShakeRx_type(8)    UARX;
    `BUS_ShakeTx_type(8)    UATX;

    // Register & Memory busses
    wire [ 4: 0] REG_ra1, REG_ra2, REG_wa;
    wire [31: 0] REG_rd1, REG_rd2, REG_wd;
    wire REG_we;
    wire            IMEM_ena,                   DMEM_ena;
    wire [11: 0]    IMEM_addra, IMEM_addrb,     DMEM_addra;
    wire [31: 0]    IMEM_dina,  IMEM_doutb,     DMEM_douta, DMEM_dina;
    wire [ 3: 0]    IMEM_wea,                   DMEM_wea;
    assign IMEM_ena = 1'b1;
    assign DMEM_ena = 1'b1;
    assign IMEM_wea = 4'b0000;
    assign DMEM_wea = 4'b0000;

    wire FWD_R1 = 1'b0, FWD_R2 = 1'b0;
    wire [31: 0] FWD_RValue = 32'd0;

    
    /* Naming conventions:
        SUFFIX for stage code (WF, DX, M) == (WriteBack-InstFetch, Decode-Execute, Memory)
        xxxSS_  : Value unstable during given stage (but stable at posedge exit)
                    Typical output of a stage/module (headed to next stage somehow).
        xxx_SS_ : As with SS_ except is already REGISTER'd at exit of output stage
                    Output is from an internal component that is synchronous.
        xxx_SS  : Value stable during entire given stage
                    Output of a prior stage after being registered by pipeline reg,
                    used as input to a given stage.
    */
    
    // Forward declare wires to explicitly feedback to prior stages
    wire [31: 0] #1 PCNext_DX_WF_;
    wire [ 4: 0] #1 WBKReg_M_WF_;
    wire [31: 0] #1 WBKDat_M_WF_;
    
    assign REG_wa = WBKReg_M_WF_,   REG_wd = WBKDat_M_WF_,  REG_we = !stl;

    // Declare outputs of WF stage
    wire [31: 0] PC_WF_, INST_WF_;
    StageWF s_WF    // WF STAGE itself
    (   .CPUGlobal(CPUGlobal),
        .IMEM_read_addr (IMEM_addrb),   .IMEM_read_data(IMEM_doutb),
    //Inputs
        .PCNext         (PCNext_DX_WF_),
    //Outputs
        .PC             (PC_WF_),       .INST       (INST_WF_)
    );
    
    // Pipeline border: WF/DX
    wire [31: 0] PC_DX, INST_DX;
    PipelineRegister    #( .PreRegistered(1)   // Is registered for us in prior stage
        ) REG_PC_DX         ( .CPUGlobal(CPUGlobal),    .In(PC_WF_),        .Out(PC_DX) );
    PipelineRegister    #( .PreRegistered(1)   // Is registered for us in prior stage
        ) REG_INST_DX       ( .CPUGlobal(CPUGlobal),    .In(INST_WF_),      .Out(INST_DX) );

    // Mini-forwarding calculation
    wire [31: 0] FWD_rd1 = (FWD_R1) ? FWD_RValue : REG_rd1;
    wire [31: 0] FWD_rd2 = (FWD_R2) ? FWD_RValue : REG_rd2;

    // Declare outputs of DX stage
    `BUS_ICTL_type IControlDX_;
    wire [31: 0] ALUOutDX_, R2ValueDX_, PCPLUS8DX_;
    StageDX s_DX
    ( .CPUGlobal(CPUGlobal),
        .REG_R1_    (REG_ra1),          .REG_R2_    (REG_ra2),
        .REG_D1_    (FWD_rd1),          .REG_D2_    (FWD_rd2),
    //Inputs
        .PC         (PC_DX),            .INST       (INST_DX),
    //Outputs
        .IControl_  (IControlDX_),
        .ALUOut_    (ALUOutDX_),
        .R2Value_   (R2ValueDX_),
        .PCPLUS8_   (PCPLUS8DX_),
    //Feedbacks
        .PCNext_    (PCNext_DX_WF_) // Feedback to WF stage
    );
    
    // Pipeline border: DX/M
    `BUS_ICTL_type IControl_M;
    wire  [31: 0] ALUOut_M;
    wire  [31: 0] R2Value_M;
    wire  [31: 0] PCPLUS8_M;
    PipelineRegister #( .Width(`BUS_ICTL_width)
        ) REG_IControl_M    ( .CPUGlobal(CPUGlobal),    .In(IControlDX_),   .Out(IControl_M) );
    PipelineRegister #( .Width(32)
        ) REG_ALUOut_M      ( .CPUGlobal(CPUGlobal),    .In(ALUOutDX_  ),   .Out(ALUOut_M  ) );
    PipelineRegister #( .Width(32)
        ) REG_R2Value_M     ( .CPUGlobal(CPUGlobal),    .In(R2ValueDX_ ),   .Out(R2Value_M ) );
    PipelineRegister #( .Width(32)
        ) REG_PCPLUS8_M     ( .CPUGlobal(CPUGlobal),    .In(PCPLUS8DX_ ),   .Out(PCPLUS8_M ) );
    
    StageM  s_M
    (   .CPUGlobal(CPUGlobal),
    //Inputs
        .IControl   (IControl_M),
        .ALUOut     (ALUOut_M),
        .R2Value    (R2Value_M),
        .PCPLUS8    (PCPLUS8_M),
    //Outputs
    //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_),     .WBK_Val_   (WBKDat_M_WF_)
    );
    

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
    (   .clka(clk),               // Clocks of a feather
        .ena    (DMEM_ena),     .addra  (DMEM_addra),   // One DMEM port...
        .douta  (DMEM_douta),                           //  for data read...
        .dina   (DMEM_dina),    .wea    (DMEM_wea)      //  & data write
    );
    
    imem_blk_ram IMEM
    (   .clka(clk), .clkb(clk),    // Clocks of a feather
        .ena    (IMEM_ena),     .addra  (IMEM_addra),   // Separate IMEM port...
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
    
    initial begin
        $display ("-   -   -   -   -   -   -   -   -   -   -   -");
    end
    
    reg[8:0] DBG_cycle, DBG_step;
    always@(rst, stl) begin
        $display("=============================================");
        $display("CTL-: C %h  R %h  S %h", clk, rst, stl);
        $strobe ("CTL+: C %h  R %h  S %h", clk, rst, stl);
        $strobe ("+++++++++++++++++++++++++++++++++++++++++++++");
        if (rst) begin
            DBG_cycle = 'bz;  DBG_step = 'bz;
        end else if (DBG_cycle[0] === 1'bz) begin
            DBG_cycle = 0;  DBG_step = 0;
        end
    end
    
    always@(posedge clk) if (DBG_cycle >= 0) begin:DBG_RUN_POS
        $display("%d] -   -   -   -   -   -   -   -   -   -   -   -", DBG_cycle);
        $display("%d] RST: %d   STL: %d   STEP: %d", DBG_cycle, rst, stl, DBG_step);
        $display("%d] WF/DX: %h %h", DBG_cycle, PC_DX, INST_DX);
        $display("%d] DX/M : %h %h %h", DBG_cycle, ALUOut_M, R2Value_M, PCPLUS8_M);
        $display("%d]      : %b", DBG_cycle, IControl_M);
        $display("%d] -   -   -   -   -   -   -   -   -   -   -   -", DBG_cycle);
        DBG_cycle = DBG_cycle + 1;
        if (!stl) DBG_step = DBG_step + 1;
        if (DBG_step > (15)) begin
            $display("Ran %d / %d", DBG_cycle, DBG_step);
            $finish();
         end
    end
    
    always@* begin
        $display(" (%d) CTL DX %b", DBG_cycle, IControlDX_);
    end
    always@* begin
        if ((REG_ra1 >= 0) || (REG_ra2 >= 0)) begin
            $display(" REGR: S1(%h,%d)=%h (%d)", REG_ra1, REG_ra1, REG_rd1, REG_rd1);
            $display("     : S2(%h,%d)=%h (%d)", REG_ra2, REG_ra2, REG_rd2, REG_rd2);
        end
    end
    
// synthesis translate_on
    
endmodule
