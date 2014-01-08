`include "cpuglobal.vh"

/*
**  Just a simple register w/synchronous-reset specified as a constant.
**    This had been experimental multi-mode (reg/sync-ctl-latch/passreset/passthru).
*/
module PipelineRegister #(
    parameter DD=`COLT45_DD,
    parameter Width=0,
    ResetValue={Width{1'b0}}
)(
    input clk, rst, stall,
    input  [Width-1:0] In,
    output reg [Width-1:0] Out
);

    // Basic register with sync-reset & sync-enable (enable = !stall).
    //  Only admit new value if !stall.
    always @(posedge clk) begin
        if (rst) begin
            Out <= ResetValue;
        end else if (!stall) begin
            Out <= In;
        end //else hold value
    end

endmodule
