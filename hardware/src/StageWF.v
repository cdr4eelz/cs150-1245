`include "CPUBusses.vh"

module StageWF #(
    parameter   [31: 0] bootPC = 32'h40000000   // 2-lsb must be 0, upper nibble 4 for BIOS-ROM
) (
    inout `BUS_CPUGlobal_type CPUGlobal,
    output reg [15: 0] STEPCOUNT, STALLCOUNT,
    output         IMEM_read_bios,
    output [11: 0] IMEM_read_addr,
    input  [31: 0] IMEM_read_data,
    
    input          DOBranch,
    input  [31: 0] PCBranch,
    
    output [31: 0] PC,
    output [31: 0] INST
);
    wire  clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
    reg [31: 0] PC_REG;
    always @(posedge clk) begin //TODO: Verify stall
        if (rst) begin
            PC_REG <= bootPC;
            STEPCOUNT <= 0;
            STALLCOUNT <= 0;
        end else if (stall) begin
            STALLCOUNT <= STALLCOUNT + 1;
        end else begin
            PC_REG <= (DOBranch) ? PCBranch : (PC_REG+4);
            STEPCOUNT <= STEPCOUNT + 1;
        end
    end
    
    assign IMEM_read_bios = ( PC_REG[31:28] == 4'h4 );
    assign IMEM_read_addr[11:0] = PC_REG[13:2]; //TODO: Assert properly aligned accesses
    assign PC   = PC_REG;
    assign INST = IMEM_read_data;
    //TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
    //TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

endmodule
