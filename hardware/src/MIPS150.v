`include "CPUBusses.vh"

module MIPS150
(
    input  clk, rst, stall,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);

    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
    `BUS_ShakeRx_type(8) UARX;
    `BUS_ShakeTx_type(8) UATX;
    
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
    
    // Forward declarataions for wires that reach prior stages
    wire [31:0 ] PCNextDX_;
    
    // Declare outputs of WF stage
    wire [31:0 ] PC_WF_;
    wire [31:0 ] INST_WF_;
    StageWF s_WF    // WF STAGE itself
    (   .CPUGlobal(CPUGlobal),
        .IMEM_read_addr(IMEM_addrb), .IMEM_read_data(IMEM_doutb),
    //Inputs
        .PCNext(PCNextDX_),
    //Outputs
        .PC(PC_WF_), .INST(INST_WF_)
    );
    
    // Pipeline border: WF/DX
    wire [31:0 ] PC_DX   = PC_WF_;   // Is registered for us in prior stage
    wire [31:0 ] INST_DX = INST_WF_; //      "
    
    // Declare outputs of DX stage
    // ...
    StageDX s_DX
    (   .CPUGlobal(CPUGlobal),
    //Inputs
        .PC(PC_DX), .INST(INST_DX),
    //Outputs
        .PCNext_(PCNextDX_)
    );
    
    reg  [31:0 ] PC_M;
    always@(posedge clk) PC_M = PC_DX;
    
    StageM  s_M
    (   .CPUGlobal(CPUGlobal)
    //Inputs
    
    //Outputs
    );
    
    
    // Key components indirectly wired elsewhere
    
    dmem_blk_ram DMEM
    (   .clka(clk),               // Clocks of a feather
        .ena(DMEM_ena), .addra(DMEM_addra),     // One DMEM port...
        .douta(DMEM_douta),                     //  for data read...
        .dina(DMEM_dina), .wea(DMEM_wea)        //  & data write
    );
    
    imem_blk_ram IMEM
    (   .clka(clk), .clkb(clk),    // Clocks of a feather
        .ena(IMEM_), .addra(IMEM_addra),        // Separate IMEM port...
        .dina(IMEM_dina), .wea(IMEM_wea),       //  for inst write...
                                                // ...VS...
        .addrb(IMEM_addrb), .doutb(IMEM_doutb)  //  inst fletch
    );
    
    UART uart
    (   .Clock(clk), .Reset(rst),  // Clocks of a feather
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        .DataIn(        `ShakeRx_DataIn(8,UARX)),
        .DataInValid(   `ShakeRx_DataInValid(8,UARX)),
        .DataInReady(   `ShakeRx_DataInReady(8,UARX)),
        .DataOut(       `ShakeTx_DataOut(8,UATX)),
        .DataOutValid(  `ShakeTx_DataOutValid(8,UATX)),
        .DataOutReady(  `ShakeTx_DataOutReady(8,UATX))
    );

endmodule
    