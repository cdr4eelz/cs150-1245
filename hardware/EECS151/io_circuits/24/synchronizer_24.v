// COPIED FROM 2024 PROJECT SKELETON

`timescale 1ns/1ns

module synchronizer_24 #(parameter WIDTH = 1) (
  input [WIDTH-1:0] async_signal,
  input clk,
  output [WIDTH-1:0] sync_signal
);

    reg [WIDTH-1:0] ff1;
    reg [WIDTH-1:0] ff2;

    assign sync_signal = ff2;
    always @ (posedge clk) begin
        ff1 <= async_signal;
        ff2 <= ff1;
    end

endmodule
