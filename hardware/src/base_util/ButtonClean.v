module ButtonClean #(
    parameter   Width       = 1,
                BounceWidth = 16,
                SimWidth    = 4
) (
    input   wire Clock,
    input   wire Reset,
    input   wire [Width-1:0] IN,
    output  wire [Width-1:0] OUT
);
    wire [Width-1:0] synched;

    Synchronizer #(
        .Width(Width)
    ) syncher (
        .Clock(Clock),
        .async_signal(IN),
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
            .Out(OUT[i]),
            .Half( /* Unused */ )
        );
    end
endmodule
