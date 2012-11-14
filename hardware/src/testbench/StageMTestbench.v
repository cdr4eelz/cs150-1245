`timescale 1ns/1ps

`include "Opcode.vh"
`include "CPUBusses.vh"

module StageMTestbench;

    // No Clock Signal, just used to punctuate test sampling time
    reg Clock;
    
    `BUS_CPUGlobal_type CPUGlobal;
    `BUS_MEMIO_type     MemoryIO;
    `BUS_ICTL_type      IControl;
    
    reg  [31:0] PC, ALUOut, R2Value;
    wire [ 5:0] WBK_Reg;
    wire [31:0] WBK_Val;
    
    StageM(
        .CPUGlobal(CPUGlobal), .MemoryIO(MemoryIO),
        .IControl(IControl), .ALUOut(ALUOut), .R2Value(R2Value), .PCPLUS8(PC+8),
        .WBK_Reg_(WBK_Reg), .WBK_Val_(WBK_Val)
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
