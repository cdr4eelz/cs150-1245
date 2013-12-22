`include "cpuglobal.vh"

/* (See bottom for comments)
**  Abstraction of inter-stage register'd value.
*/
module PipelineRegister #(
    parameter DD=`COLT45_DD,
    parameter Mode=0 /*0-3=(Reg,Latch,PassReset,PassThru)*/, 
    parameter Width=0, ResetValue={Width{1'b0}}
)(
    input `BUS_CPUGlobal_type CPUGlobal,
    input  [Width-1:0] In,
    output reg [Width-1:0] Out
);

    wire clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

//TODO: Try to LATCHIEMUX with regular sync element at end of it's combo-logic
generate
    if (Mode == 3) begin:PASSTHRU
        always @(*) Out = In;
    end else if (Mode == 2) begin:PASSRESET
        // *Synchronously* apply reset but totally IGNORE enable.
        reg SyncReset;
        always @(posedge clk) begin
            SyncReset <= rst;
        end
        always @(*) begin
            if (SyncReset)
                Out = ResetValue;
            else
                Out = In; // Both cases fully covered
        end
    end else if (Mode == 1) begin:LATCHIEMUX
        // *Synchronously* consider reset & enable and
        //   register associated override value on posedge clk,
        //   but if not overridden, track In live during full cycle.
        // Appropriately hold ambiguous value until reset or enable.
        reg OverRide;
        reg  [Width-1:0] OverOut;
        always @(posedge clk) begin
            OverRide <= rst || stall;
            if (rst) OverOut <= ResetValue;
            else if (!OverRide) OverOut <= In; //NOTE: Uses *OLD* !OverRide!
        end
        always @(*) Out = (OverRide) ? OverOut : In;
    end else begin:REGGIEREG
        // Basic register with sync-reset & sync-enable (enable = !stall).
        //  Only admit new value if !stall.
        always @(posedge clk) begin
            if (rst) Out <= ResetValue;
            else if (!stall) Out <= In;
            //else hold value
        end
    end
endgenerate

endmodule
