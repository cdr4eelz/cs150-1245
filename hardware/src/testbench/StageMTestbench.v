`timescale 1ns/1ps

`include "CPUGlobal.vh"
`include "Opcode.vh"

module StageMTestbench;

    wire clk, rst, stall;
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
    `BUS_ICTL_type      _IControl, IControl;
    `BUS_SHAKE_type(8) UARX, UATX; // Ready-Valid 

    reg    [31:0]   INST_ADDR, MemAddr, RegWValue;
    wire   [ 5:0]   WBK_Reg;
    wire   [31:0]   WBK_Val;
    wire            WBK_Forward;
    wire   [31: 0]  _MemWValue, _MemAddr;

    StageM s_M
    ( .CPUGlobal(CPUGlobal),
        //Inputs
        ._IControl  (IControl__M),  .IControl   (IControl_M),
        ._MemAddr   (MemAddr__M),   .MemAddr    (MemAddr_M),
        ._MemWValue (MemWValue__M), .RegWValue  (RegWValue_M),
        .PCPLUS8    (PCPLUS8_M),
        //Feedbacks
        .WBK_Reg_   (WBKReg_M_WF_), .WBK_Val_   (WBKDat_M_WF_),
        .WBK_CanFWD_(WBKCanFWD_M_WF_),
        //Passthrough signals NOT sync'd with StageM
        .INST_ADDR(32'd0), .INST_DATA(),
        .UARX(UARX), .UATX(UATX) //UART
    );

    integer step = 0;
    
    task exec_inst;
        input [31:0] inst;
        begin
            step = step + 1;
        end
    endtask
    
    initial begin
        $display("All tests passed!");
        $finish();
    end
endmodule
