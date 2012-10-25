`include "CPUBusses.vh"

module	PipelineRegister #(
    parameter  PreRegistered = 0,
                Width=32,
                ResetValue={Width{1'b0}}
) (
    inout `BUS_CPUGlobal_type CPUGlobal,
    input  [Width-1:0] In,
    output [Width-1:0] Out
);
    wire Clock      = `CPUGlobal_CLK(CPUGlobal);
    wire Reset      = `CPUGlobal_RST(CPUGlobal);
    wire Enable     = !`CPUGlobal_STL(CPUGlobal);
    reg [Width-1:0] OverOut;

    generate if (PreRegistered) begin:LATCHIEMUX
        // Synchronously consider reset & enable and
        //   register associated override value on posedge clk,
        //   but if not overridden, track In live during full cycle.
        // Appropriately hold ambiguous value until reset or enable.
        reg OverRide;
        always @ (posedge Clock) begin
            OverRide <= Reset || !Enable;
            if (Reset)          OverOut <= ResetValue;
            else if (!OverRide) OverOut <= In; // This is the OLD OverRide!
        end
        assign Out = (OverRide) ? OverOut : In;
    end else begin:REGGIEREG
        // Basic register with sync reset & sync enable
        //  where enable locks in prior value when low.
        always @ (posedge Clock) begin
            if (Reset)          OverOut <= ResetValue;
            else if (Enable)    OverOut <= In;
        end
        assign Out = OverOut;
    end endgenerate
endmodule
