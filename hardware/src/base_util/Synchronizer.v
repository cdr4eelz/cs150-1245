// COPIED FROM 2019 PROJECT SKELETON, then implemented two-flop sync...

module Synchronizer #(
    parameter Width = 1
) (
    input Clock,
    input [Width-1:0] async_signal,
    output [Width-1:0] sync_signal
);
    // Create your 2 flip-flop synchronizer here
    // This module takes in a vector of 1-bit asynchronous (from different clock domain or not clocked) signals
    // and should output a vector of 1-bit synchronous signals that are synchronized to the input clk

    // Remove this line once you create your synchronizer
    ////assign sync_signal = 0;

    (* SHREG_EXTRACT="NO", EQUIVALENT_REGISTER_REMOVAL="OFF", KEEP="TRUE", S="TRUE",
       ASYNC_REG="TRUE", OPTIMIZE="OFF" *)
    reg [Width-1:0] flops [0:1];  // ASYNC_REG is the important property, others are overkill!
    // ASYNC_REG prevents removal of the flip-flops by optimization. It also indicates that the
    //    the two flops should be placed as close together as possible (increasing meta-stability).

    always @(posedge Clock) begin
        flops[0] <= async_signal;
        flops[1] <= flops[0];
    end

    assign sync_signal = flops[1];
endmodule
