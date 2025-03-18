// COPIED FROM 2024 PROJECT SKELETON

`timescale 1ns/1ns

// This module instantiates the synchronizer -> debouncer -> edge detector signal chain for button inputs
module button_parser_24 #(
  parameter WIDTH = 1,
  parameter SAMPLE_CNT_MAX = 25000,
  parameter PULSE_CNT_MAX = 150
) (
  input clk,
  input [WIDTH-1:0] in,
  output [WIDTH-1:0] out
);

  wire [WIDTH-1:0] synchronized_signals;
  wire [WIDTH-1:0] debounced_signals;

  synchronizer_24 # (
    .WIDTH(WIDTH)
  ) button_synchronizer (
    .clk(clk),
    .async_signal(in),
    .sync_signal(synchronized_signals)
  );

  debouncer_24 # (
    .WIDTH(WIDTH),
    .SAMPLE_COUNT_MAX(SAMPLE_CNT_MAX),
    .PULSE_COUNT_MAX(PULSE_CNT_MAX)
  ) button_debouncer (
    .clk(clk),
    .glitchy_signal(synchronized_signals),
    .debounced_signal(debounced_signals)
  );

  edge_detector_24 # (
    .WIDTH(WIDTH)
  ) button_edge_detector (
    .clk(clk),
    .signal_in(debounced_signals),
    .edge_detect_pulse(out)
  );

endmodule
