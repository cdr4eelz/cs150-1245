`include "cpuglobal.vh"
//TODO: Split into two modules now that experimentation phase is over

/*
**  Abstraction of inter-stage register'd or latch'd value at pipeline stage borders
*/
module PipelineBorder #(
    parameter DD=`COLT45_DD,
    parameter Mode=0 /*0-3=(Reg,LatchieMUX,PassReset,PassThru)*/, 
    parameter Width=0, ResetValue={Width{1'b0}}
)(
    input clk, rst, stall,
    input  [Width-1:0] In,
    output reg [Width-1:0] Out
);

//TODO: Eliminate LATCHIEMUX use altogether
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
        reg [Width-1:0] OverOut;
        reg OverRide;
        always @(posedge clk) begin //Synchronously capture value & stall
            if (rst) begin
                OverOut <= ResetValue;
                OverRide <= 1'b1;
            end else begin
                OverRide <= stall; //Sample stall synchronously for next cycle's OverRide state
                if (!OverRide) OverOut <= In; //If last-cycle wasn't OverRiden, admit new potential OverOut
            end
        end
        always @(*) Out = (OverRide) ? OverOut : In; //The latchie portion (but based on synchronized OverRide)
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
