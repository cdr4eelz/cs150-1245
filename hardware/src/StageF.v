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
    output reg [COUNTERWIDTH-1:0] CycleCount, StallCount, StepCount,
    input ResetCounters
);

    reg [31: 0] PC_REG;
    always @(posedge clk) begin
        if (rst) begin
            PC_REG <= BOOTPC;
        end else if (!stall) begin
            PC_REG <= PCNext_;
        end

        if (rst || ResetCounters) begin
            CycleCount <= 0;
            StallCount <= 0;
            StepCount <= 0;
        end else begin
            CycleCount <= CycleCount+1;
            if (stall) begin
                StallCount <= StallCount+1;
            end else begin
                StepCount <= StepCount+1;
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
