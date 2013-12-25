`include "cpuglobal.vh"

module StageF #(
    parameter [31:0] BOOTPC=32'h4_000_0000, // BIOS base address
    parameter COUNTERWIDTH=32
)(
    input clk, rst, stall,
    //Program Counter outputs (3 varieties)
    output [31: 0] PC, PC4, PCNext_,
    //Branch/Interrupt control to deviate from PC+4
    input  [31: 0] PCBranch,
    input          DOBranch,
    //Instruction related counters & reset (synchronous)
    output reg [COUNTERWIDTH-1:0] CNT_Cycle, CNT_Stall, CNT_Step
);

    reg [31: 0] PC_REG;
    always @(posedge clk) begin
        //Trying to make it easy to map into LUT/SYNC-FF(reset/enable)
        if (rst) begin:_PC_
            PC_REG <= BOOTPC;
        end else if (!stall) begin
            PC_REG <= PCNext_;
        end

        //Hoping to map to nice counters (could use utility modules instead)
        if (rst) begin:_CPU_COUNTERS_
            {CNT_Cycle, CNT_Stall, CNT_Step} <= 0;
        end else begin
            CNT_Cycle <= CNT_Cycle+1;
            if (stall) begin
                CNT_Stall <= CNT_Stall+1;
            end else begin
                CNT_Step <= CNT_Step+1;
            end
        end
    end

    assign PC = PC_REG;
    assign PC4 = (PC_REG+4);
    assign PCNext_ = (DOBranch) ? PCBranch : PC4;

    //TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
    //TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
    //TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

endmodule
