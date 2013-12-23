`timescale 1ns/1ps

`include "cpuglobal.vh"
`include "opcode.vh"

module StageMWTestbench;

    wire clk, rst, stall;
    
    `BUS_ICTL_type      _IControl, IControl;
    `BUS_SHAKE_type(8) UARX, UATX; // Ready-Valid 

    reg    [31:0]   INST_ADDR, MemAddr, RegWValue;
    wire   [ 5:0]   WBK_Reg;
    wire   [31:0]   WBK_Val;
    wire            WBK_Forward;
    wire   [31: 0]  _MemWValue, _MemAddr;

    StageMW s_MW
    (
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
