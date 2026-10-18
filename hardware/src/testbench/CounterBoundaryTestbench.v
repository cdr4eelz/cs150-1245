`timescale 1ns/1ps

module CounterBoundaryTestbench;
    reg Clock;
    reg Reset;
    reg Set;
    reg Load;
    reg Enable;
    reg [3:0] In;
    wire [3:0] UpCount;
    wire [3:0] DownCount;

    Counter #(
        .Width(4), .Limited(1), .Initial(4'h0),
        .ResetValue(4'h0), .SetValue(4'hf)
    ) UpCounter (
        .Clock(Clock), .Reset(Reset), .Set(Set), .Load(Load),
        .Enable(Enable), .In(In), .Count(UpCount)
    );

    Counter #(
        .Width(4), .Limited(1), .Down(1), .Initial(4'hf),
        .ResetValue(4'hf), .SetValue(4'h0)
    ) DownCounter (
        .Clock(Clock), .Reset(Reset), .Set(Set), .Load(Load),
        .Enable(Enable), .In(In), .Count(DownCount)
    );

    task tick;
        begin
            #5 Clock = 1;
            #5 Clock = 0;
        end
    endtask

    task check_counts;
        input [3:0] expected_up;
        input [3:0] expected_down;
        begin
            #1;
            if (UpCount !== expected_up || DownCount !== expected_down) begin
                $display("FAIL: expected up=%h down=%h, got up=%h down=%h",
                         expected_up, expected_down, UpCount, DownCount);
                $finish;
            end
        end
    endtask

    integer i;
    initial begin
        Clock = 0;
        Reset = 0;
        Set = 0;
        Load = 0;
        Enable = 0;
        In = 0;
        check_counts(4'h0, 4'hf);

        Enable = 1;
        for (i = 0; i < 15; i = i + 1) tick;
        check_counts(4'hf, 4'h0);
        tick;
        check_counts(4'hf, 4'h0);

        Enable = 0;
        Load = 1;
        In = 4'h5;
        tick;
        check_counts(4'h5, 4'h5);
        Load = 0;
        tick;
        check_counts(4'h5, 4'h5);

        Reset = 1;
        tick;
        check_counts(4'h0, 4'hf);
        Reset = 0;

        $display("All Counter boundary tests passed.");
        $finish;
    end
endmodule
