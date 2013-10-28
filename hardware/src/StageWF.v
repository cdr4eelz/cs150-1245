`include "CPUBusses.vh"

module StageWF #(
    parameter [31:0] BOOTPC=32'h40000000,
    parameter COUNTERWIDTH=32
)(
    inout `BUS_CPUGlobal_type CPUGlobal,
    output [31: 0] INST_ADDR,

    input          DOBranch,
    input  [31: 0] PCBranch,

    output reg [COUNTERWIDTH-1:0] STEPCOUNT, STALLCOUNT
);
    wire  clk, rst, stall;
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

    assign INST_ADDR = PC_REG;
    //TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
    //TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

endmodule
