module ButtonClean #(
    parameter   Width       = 1,
                BounceWidth = 16,
                SimWidth    = 4
) (
    input Clock,
    input Reset,
    input [Width-1:0] Inputs,
    output reg [Width-1:0] Outputs
);
    wire [Width-1:0] synched;

    Synchronizer #(
        .Width(Width)
    ) syncher (
        .Clock(Clock),
        .async_signal(Inputs),
        .sync_signal(synched)
    );

    genvar i;
    for (i = 0; i < Width; i = i + 1) begin
        Debouncer #(
            .Width(BounceWidth),
            .SimWidth(SimWidth)
        ) DbounceIt (
            .Clock(Clock),
            .Reset(Reset),
            .Enable(1'b1),
            .In(synched[i]),
            .Out(Outputs[i]),
            .Half( /* Unused */ )
        );
    end
endmodule
