`include "../cpuglobal.vh"

/*
**  Just a simple register w/synchronous-reset specified as a constant.
**    This had been experimental multi-mode (reg/sync-ctl-latch/passreset/passthru).
*/
module PipelineRegister #(
    parameter DD=`COLT45_DD,
    parameter Width=0, //Instantiated module had best override this! :)
    ResetValue={Width{1'b0}}
)(
    input  wire clk, rst, stall,
    input  wire[Width-1:0] In,
    output wire[Width-1:0] Out
);

    reg [Width-1:0] pipereg = ResetValue;

    // Basic register with sync-reset & Clock-Enable (CE = !stall).
    //  Only admit new value if !stall.
    always @(posedge clk) begin
        if (rst) begin
            pipereg <= ResetValue;
        end else if (!stall) begin
            pipereg <= In;
        end //else hold value
    end

    assign Out = pipereg;

endmodule
