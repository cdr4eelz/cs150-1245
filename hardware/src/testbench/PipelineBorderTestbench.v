`timescale 1ns/1ps

`include "cpuglobal.vh"

module PipelineBorderTestbench;
    reg clk, rst, stall;
    reg [3:0] IN;
    wire [3:0] outA, outB;

    PipelineBorder #(
        .Mode(0), .Width(4), .ResetValue(4'hE)
    ) DUT_REGGIE ( .clk(clk), .rst(rst), .stall(stall),
        .In(IN),    .Out(outA)
    );
    PipelineBorder #(
        .Mode(1), .Width(4), .ResetValue(4'h3)
    ) DUT_LATCHY ( .clk(clk), .rst(rst), .stall(stall),
        .In(IN),    .Out(outB)
    );

    integer testnum = 0, failnum = 0;
    reg [3:0] wantA, wantB;
    wire pass = ((wantA === outA) || (wantB === outB));

    task WANT;
        input [3:0] tWantA;
        input [3:0] tWantB;
    begin
        {wantA, wantB} <= {tWantA, tWantB};
        $display("%d WANT: %h, %h", testnum, wantA, wantB);
        if (!pass) begin
            failnum = failnum + 1;
            $display("%d GOT : %h, %h  [%d]",  testnum, outA,  outB, failnum);
//            $finish();
        end
        testnum = testnum + 1;
    end endtask

    initial begin
        //Testing a semi-latchy device, so monitor every change in inputs
        $monitor("clk:%b rst:%b stall:%b | IN:%h", clk, rst, stall, IN);
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1; WANT(   4'bx,   4'bx    );
        #1 IN = 0; #1 stall = 0;
        #1; WANT(   4'bx,   4'bx    );
        clk = 1;
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1 rst = 0;
        #1; WANT(   4'bx,   4'bx    );
        clk = 1;
        #1; WANT(   4'b0,   4'b0    );
        clk = 0;
        #1 IN = 0; #1 rst = 1; #1 stall = 0;
        #1; WANT(   4'b0,   4'b0    );
        clk = 1;
        #1; WANT(   4'hE,   4'h3    );
        clk = 0;
        #1 stall = 1;
        #1; WANT(   4'hE,   4'h3    );
        clk = 1;
        #1; WANT(   4'hE,   4'h3    );
        clk = 0;
        #1 rst = 0;
        #1; WANT(   4'hE,   4'h3    );
        clk = 1;
        #1; WANT(   4'hE,   4'h3    );
        clk = 0;
        #1; stall = 0;
        #1; WANT(   4'hE,   4'h3    );
        clk = 1;
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1; IN = 5;
        #1; WANT(   4'bx,   4'd5    );
        clk = 1;
        #1; WANT(   4'd5,   4'd5    );
        IN = 2;
        #1; WANT(   4'd5,   4'd2    );
        clk = 0;
        #1; stall = 1; #1; IN = 9;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'd5,   4'd9    );
        clk = 0;
        #1; IN = 15;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'd5,   4'd9    );
        clk = 0;
        #1; IN = 13; stall = 0;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'hD,   4'hD    );
        clk = 0;

        if (failnum === 0)
            $display("All tests passed!");
        else
            $display("%d tests failed :(", failnum);

        $finish();
    end

endmodule
