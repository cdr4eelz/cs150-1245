`include "CPUBusses.vh"

/* (See bottom for comments)
**  Abstraction of inter-stage register'd value.
*/ 
module	PipelineRegister #(
    parameter Width=0,
    parameter PreRegistered=0,  // TODO: Rename since "pre/post" is not relevant
    parameter ResetValue={Width{1'b0}},
    parameter ClockBlip=0, OutDelay=0
)(
    input `BUS_CPUGlobal_type CPUGlobal,
    input  [Width-1:0] In,
    output [Width-1:0] Out
);
    wire clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    reg  [Width-1:0] OverOut;
    wire [Width-1:0] #OutDelay _Out_;  // Hang the old value out for a tick
    
    // Make a little Z-BLIP to highlight poopigation through combinational logic based off of static elements
    generate if (ClockBlip) begin:BLIP
        reg Blip;
        always @ (posedge clk) begin
            Blip <= #1 (!stall && !rst);
            Blip <= #2 1'b0;
        end
        assign Out = (Blip) ? 'bz : _Out_;
    end else begin
        assign Out = _Out_;
    end endgenerate
    
    generate if (PreRegistered) begin:LATCHIEMUX
        // Synchronously consider reset & enable and
        //   register associated override value on posedge clk,
        //   but if not overridden, track In live during full cycle.
        // Appropriately hold ambiguous value until reset or enable.
        reg OverRide;
        always @ (posedge clk) begin
            OverRide <= rst || stall;
            if (rst) OverOut <= ResetValue;
            else if (!OverRide) OverOut <= In; // Important to use *OLD* !OverRide!
        end
        assign _Out_ = (OverRide) ? OverOut : In;
    end else begin:REGGIEREG
        // Basic register with sync reset & sync enable
        //  where enable locks in prior value when low.
        always @ (posedge clk) begin
            if (rst) OverOut <= ResetValue;
            else if (!stall) OverOut <= In;
        end
        assign _Out_ = OverOut;
    end endgenerate
endmodule

/* Abstract pipeline separation & registering even when
** another synchronous element is doing the actual registering
** of the value at hand.  In that case, set PreRegistered=1 so
** that this "register" then behaves like a latch.  Note that
** in this asynchronous latch mode, both Reset and Stall are
** considered only on posedge Clock, making them synchronous.
** Care is taken not to latch values prematurely, nor repeatedly.
** 
** In BOTH modes, an arbitrary reset value may be imposed.
** These features allow identical treatment in regards to key
** pipeline register behavior, even if butted up against a
** pre-registering synchronous element.
**
** Since transitions between pipeline stages are paramount to
** understanding CPU state, some debugging tricks may also be
** applied universally via this abstraction.  The OutDelay &
** ClockBlip help resultant waveforms to emphasize critical
** transitions & facilitate use of delays in subsequent
** combinational logic to highlight datapath flow.
*/
