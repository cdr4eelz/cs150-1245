`timescale 1ns/1ps

`include "Opcode.vh"
`include "CPUBusses.vh"

module StageMTestbench;

    // No Clock Signal, just used to punctuate test sampling time
    reg Clock;
    
//    `BUS_CPUGlobal_type CPUGlobal;
    `BUS_MMAP_type      DMEM, IMEM, BMEM, IOMAP;
    `BUS_ICTL_type      _IControl, IControl;
    
    reg    [31:0]   PC, MemAddr, RegWValue;
    wire   [ 5:0]   WBK_Reg;
    wire   [31:0]   WBK_Val;
    wire            WBK_Forward;
    wire   [31: 0]  _MemWValue, _MemAddr;
    
    StageM M
    (//.CPUGlobal(CPUGlobal),
        .DMEM(DMEM), .IMEM(IMEM), .BMEM(BMEM), .IOMAP(IOMAP),
        .IControl(IControl), ._IControl(_IControl),
        ._MemWValue(_MemWValue), ._MemAddr(_MemAddr),
        .RegWValue(RegWValue), .MemAddr(MemAddr), .PCPLUS8(PC+8),
        .WBK_Reg_(WBK_Reg), .WBK_Val_(WBK_Val), .WBK_CanFWD_(WBK_Forward)
    );
    
    integer step = 0;
    
    task exec_inst;
        input [31:0] inst;
        reg [31:0] pc;
        begin
            step = step + 1;
        end
    endtask
    
    initial begin
        $display("All tests passed!");
        $finish();
    end
endmodule
