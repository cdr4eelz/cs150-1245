`include "CPUBusses.vh"

module StageWF #(
    parameter [31:0] BOOTPC=32'h4_000_0000, // BIOS base address
    parameter COUNTERWIDTH=32
)(
    input `BUS_CPUGlobal_type CPUGlobal,
    output [31: 0] PC,

    input  [31: 0] PCBranch,
    input          DOBranch,

    output reg [COUNTERWIDTH-1:0] STEPCOUNT, STALLCOUNT
);

    wire clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

    reg [31: 0] PC_REG;
    always @(posedge clk) begin //TODO: Verify stall
        if (rst) begin
            PC_REG <= BOOTPC;
            STEPCOUNT <= 0;
            STALLCOUNT <= 0;
        end else if (stall) begin
            STALLCOUNT <= STALLCOUNT + 1;
        end else begin
            PC_REG <= (DOBranch) ? PCBranch : (PC_REG+4);
            STEPCOUNT <= STEPCOUNT + 1;
        end
    end

    assign PC = PC_REG;
    //TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
    //TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
    //TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

endmodule
