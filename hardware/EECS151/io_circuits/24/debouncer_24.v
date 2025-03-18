// COPIED FROM 2024 PROJECT SKELETON & LAB REFERENCE

`timescale 1ns/1ns

module debouncer_24 #(
    parameter WIDTH = 1,
    parameter SAMPLE_COUNT_MAX = 25000,
    parameter PULSE_COUNT_MAX = 150,
    parameter WRAPPING_COUNTER_WIDTH = $clog2(SAMPLE_COUNT_MAX),
    parameter SATURATING_COUNTER_WIDTH = $clog2(PULSE_COUNT_MAX))
(
    input clk,
    input [WIDTH-1:0] glitchy_signal,
    output [WIDTH-1:0] debounced_signal
);
    reg [WRAPPING_COUNTER_WIDTH - 1:0] wrapping_counter = 0;
    reg [SATURATING_COUNTER_WIDTH - 1:0] saturating_counter [WIDTH-1:0];

    wire [WRAPPING_COUNTER_WIDTH - 1:0] wrapping_limit;
    assign wrapping_limit = SAMPLE_COUNT_MAX[WRAPPING_COUNTER_WIDTH - 1:0];

    wire [SATURATING_COUNTER_WIDTH - 1:0] saturating_limit;
    assign saturating_limit = PULSE_COUNT_MAX[SATURATING_COUNTER_WIDTH - 1:0];
    

    always @ (posedge clk) begin
        if (wrapping_counter == wrapping_limit) begin
            wrapping_counter <= 0;
        end
        else begin
            wrapping_counter <= wrapping_counter + 1;
        end
    end

    genvar i;
    generate for (i = 0; i < WIDTH; i = i + 1) begin:SAT_COUNTER
        always @ (posedge clk) begin
            if (glitchy_signal[i] == 0) begin
                saturating_counter[i] <= 0;
            end
            else if (glitchy_signal[i] == 1 && wrapping_counter == (wrapping_limit - 'd1) && saturating_counter[i] != saturating_limit) begin
                saturating_counter[i] <= saturating_counter[i] + 1;
            end
            else begin
                saturating_counter[i] <= saturating_counter[i];
            end
        end
    end endgenerate

    genvar j;
    generate for (j = 0; j < WIDTH; j = j + 1) begin:ASSIGN
        assign debounced_signal[j] = (saturating_counter[j] == (saturating_limit - 'd1));
    end endgenerate

    integer k;
    initial begin
        for (k = 0; k < WIDTH; k = k + 1) begin
            saturating_counter[k] = 0;
        end
    end
endmodule
