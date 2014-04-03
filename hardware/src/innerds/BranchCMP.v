`include "../cpuglobal.vh"
`include "branchcmpop.vh"

// Playing with functions to see when they help much.
// Now requires zeroing of B externally!

module BranchCMP #(
    parameter WIDTH = 32
)(
  input [2:0] branchOp,
  input signed [WIDTH-1:0] A,
  input signed [WIDTH-1:0] B,
  output doBranch
);

    function [0:0] fullCompare;
        input [2:0] cmpOp;
        input signed [WIDTH-1:0] A, B;
        begin
            fullCompare = `UNKNOWN(1); //Was 1'bx...but case is full anyway
            case(cmpOp)
                `FULLCMP_EQ:    fullCompare = (A == B);
                `FULLCMP_NE:    fullCompare = (A != B);
                `FULLCMP_LT:    fullCompare = (A <  B);
                `FULLCMP_GT:    fullCompare = (A >  B);
                `FULLCMP_GE:    fullCompare = (A >= B);
                `FULLCMP_LE:    fullCompare = (A <= B); //(A < B) || (A == B);
                `FULLCMP_False: fullCompare = 1'b0;
                `FULLCMP_True:  fullCompare = 1'b1;
            endcase
        end
    endfunction

    assign doBranch = fullCompare (branchOp, A, B);

endmodule
