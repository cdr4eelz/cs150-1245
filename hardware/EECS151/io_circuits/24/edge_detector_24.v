// COPIED FROM 2024 PROJECT SKELETON & LAB REFERENCE

`timescale 1ns/1ns

module edge_detector_24 #(
    parameter WIDTH = 1
)(
    input clk,
    input [WIDTH-1:0] signal_in,
    output [WIDTH-1:0] edge_detect_pulse
);
    reg [WIDTH-1:0] previous_values_1 = 0;
    reg [WIDTH-1:0] previous_values_2 = 0;

    always @ (posedge clk) begin
        previous_values_1 <= signal_in;
        previous_values_2 <= previous_values_1;
    end

    genvar i;
    generate for (i = 0; i < WIDTH; i = i + 1) begin: edge_detector_assign
        assign edge_detect_pulse[i] = previous_values_1[i] && !previous_values_2[i];
    end endgenerate
endmodule
