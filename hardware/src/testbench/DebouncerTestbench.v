`timescale 1ns/1ps

module DebouncerTestbench;
    reg Clock;
    reg Reset;
    reg Enable;
    reg In;
    wire LatchedOut;
    wire LatchedHalf;
    wire ContinuousOut;
    wire ContinuousHalf;

    Debouncer #(
        .Width(2), .SimWidth(2), .Continuous(0)
    ) LatchedDebouncer (
        .Clock(Clock), .Reset(Reset), .Enable(Enable), .In(In),
        .Out(LatchedOut), .Half(LatchedHalf)
    );

    Debouncer #(
        .Width(2), .SimWidth(2), .Continuous(1)
    ) ContinuousDebouncer (
        .Clock(Clock), .Reset(Reset), .Enable(Enable), .In(In),
        .Out(ContinuousOut), .Half(ContinuousHalf)
    );

    integer i;
    integer continuous_rises;
    reg previous_continuous;

    initial begin
        Clock = 0;
        forever #5 Clock = ~Clock;
    end

    initial begin
        Reset = 1;
        Enable = 0;
        In = 0;
        continuous_rises = 0;
        previous_continuous = 0;

        repeat (2) @(posedge Clock);
        @(negedge Clock);
        Reset = 0;
        Enable = 1;
        In = 1;

        for (i = 0; i < 32; i = i + 1) begin
            @(posedge Clock);
            #1;
            if (LatchedOut !== 1'b0 && LatchedOut !== 1'b1) begin
                $display("FAIL: latched output is unknown during stable input.");
                $finish;
            end
            if (ContinuousOut && !previous_continuous)
                continuous_rises = continuous_rises + 1;
            previous_continuous = ContinuousOut;

            if (LatchedOut !== 1'b1 && i >= 8) begin
                $display("FAIL: non-continuous output did not remain latched high.");
                $finish;
            end
        end

        if (continuous_rises < 2) begin
            $display("FAIL: continuous mode did not repeat while input stayed high.");
            $finish;
        end

        @(negedge Clock);
        In = 0;
        repeat (8) @(posedge Clock);
        #1;
        if (LatchedOut !== 1'b0 || ContinuousOut !== 1'b0) begin
            $display("FAIL: outputs did not settle low after stable low input.");
            $finish;
        end

        $display("All Debouncer mode tests passed.");
        $finish;
    end
endmodule
