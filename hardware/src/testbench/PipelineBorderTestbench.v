`timescale 1ns/1ps

`include "cpuglobal.vh"

module PipelineBorderTestbench;
    reg clk, rst, stall;
    reg [3:0] in;
    wire [3:0] outA, outB;

    PipelineBorder #(
        .Mode(0), .Width(4), .ResetValue(4'hE)
    ) DUT_REGGIE ( .clk(clk), .rst(rst), .stall(stall),
        .In(in),    .Out(outA)
    );
    PipelineBorder #(
        .Mode(1), .Width(4), .ResetValue(4'h3)
    ) DUT_LATCHY ( .clk(clk), .rst(rst), .stall(stall),
        .In(in),    .Out(outB)
    );

    integer testnum;
    initial testnum=0;

    task WANT;
        input [3:0] wantA;
        input [3:0] wantB;
    begin
        $display("%d WANT: %h, %h", testnum, wantA, wantB);
        if ((wantA !== outA) || (wantB !== outB)) begin
            $display("%d GOT : %h, %h",  testnum, outA,  outB);
            $finish();
        end
        testnum = testnum + 1;
    end endtask

    initial begin
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1; WANT(   4'bx,   4'bx    );
        #1 in = 0; #1 stall = 0;
        #1; WANT(   4'bx,   4'bx    );
        clk = 1;
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1 rst = 0;
        #1; WANT(   4'bx,   4'bx    );
        clk = 1;
        #1; WANT(   4'bx,   4'bx    );
        clk = 0;
        #1 in = 0; #1 rst = 1; #1 stall = 0;
        #1; WANT(   4'bx,   4'bx    );
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
        #1; in = 5;
        #1; WANT(   4'bx,   4'd5    );
        clk = 1;
        #1; WANT(   4'd5,   4'd5    );
        in = 2;
        #1; WANT(   4'd5,   4'd2    );
        clk = 0;
        #1; stall = 1; #1; in = 9;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'd5,   4'd9    );
        clk = 0;
        #1; in = 15;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'd5,   4'd9    );
        clk = 0;
        #1; in = 13; stall = 0;
        #1; WANT(   4'd5,   4'd9    );
        clk = 1;
        #1; WANT(   4'hD,   4'hD    );
        clk = 0;

        $display("All tests passed!");
        $finish();
    end

endmodule
