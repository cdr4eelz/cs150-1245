`timescale 1ns/1ps

`include "../cpuglobal.vh"

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

    task WANT;
        input [3:0] tWantA;
        input [3:0] tWantB;
    begin
        {wantA, wantB} = {tWantA, tWantB};
        #1;
        $display("%d WANT: %h, %h", testnum, wantA, wantB);
        if ((wantA !== outA) || (wantB !== outB)) begin
            failnum = failnum + 1;
            $display("%d GOT : %h, %h  [%d]",  testnum, outA,  outB, failnum);
//            $finish();
        end
        testnum = testnum + 1;
    end endtask

    initial begin
        //Testing a semi-latchy device, so monitor every change in inputs
        $monitor("clk:%b rst:%b stall:%b | IN:%h => {A:%h,B:%h}", clk, rst, stall, IN, outA, outB);
        {clk,rst,stall,IN} = {1'b0,1'b0,1'b0,4'hx};
        WANT(   4'hx,   4'hx    );
        #1 clk = 1;
        WANT(   4'hx,   4'hx    );
        #1 clk = 0;
        WANT(   4'hx,   4'hx    );
        #1 IN = 4'h1;
        WANT(   4'hx,   4'h1    );
        #1 clk = 1;
        WANT(   4'h1,   4'h1    );
        #1 IN = 4'h9;
        WANT(   4'h1,   4'h9    );
        #1 clk = 0;
        WANT(   4'h1,   4'h9    );
        #1 rst = 1;
        WANT(   4'h1,   4'h9    );
        #1 clk = 1;
        WANT(   4'hE,   4'h3    );
        #1 clk = 0;
        WANT(   4'hE,   4'h3    );
        #1 stall = 1;
        WANT(   4'hE,   4'h3    );
        #1 clk = 1;
        WANT(   4'hE,   4'h3    );
        #1 clk = 0;
        WANT(   4'hE,   4'h3    );
        #1 rst = 0;
        WANT(   4'hE,   4'h3    );
        #1 IN = 4'h8;
        WANT(   4'hE,   4'h3    );
        #1 clk = 1;
        WANT(   4'hE,   4'h3    );
        #1 clk = 0;
        WANT(   4'hE,   4'h3    );
        #1 stall = 0;
        WANT(   4'hE,   4'h3    );
        #1 clk = 1;
        WANT(   4'h8,   4'h8    );
        #1 clk = 0;
        WANT(   4'h8,   4'h8    );
        #1 IN = 5;
        WANT(   4'h8,   4'd5    );
        #1 clk = 1;
        WANT(   4'd5,   4'd5    );
        #1 IN = 4'h2;
        WANT(   4'd5,   4'd2    );
        #1 clk = 0;
        WANT(   4'd5,   4'd2    );
        #1 stall = 1;
        WANT(   4'd5,   4'd2    );
        #1 IN = 9;
        WANT(   4'd5,   4'd9    );
        #1 clk = 1;
        WANT(   4'd5,   4'd9    );
        #1 clk = 0;
        WANT(   4'd5,   4'd9    );
        #1 IN = 4'hF;
        WANT(   4'd5,   4'd9    );
        #1 clk = 1;
        WANT(   4'd5,   4'd9    );
        #1 clk = 0;
        WANT(   4'd5,   4'd9    );
        #1 stall = 0;
        WANT(   4'd5,   4'd9    );
        #1 clk = 1;
        WANT(   4'hF,   4'hF    );
        #1 clk = 0;
        #1 IN = 4'hD;
        WANT(   4'hF,   4'hD    );
        #1 clk = 1;
        WANT(   4'hD,   4'hD    );

        if (failnum === 0)
            $display("All tests passed!");
        else
            $display("%d tests failed :(", failnum);

        $finish();
    end

endmodule
