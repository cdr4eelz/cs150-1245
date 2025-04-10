//-----------------------------------------------------------------------------
//  Module: RegFile
//  Desc: An array of 32 32-bit registers
//  Inputs Interface:
//    clk: Clock signal
//    ra1: first read address (asynchronous)
//    ra2: second read address (asynchronous)
//    wa: write address (synchronous)
//    we: write enable (synchronous)
//    wd: data to write (synchronous)
//  Output Interface:
//    rd1: data stored at address ra1
//    rd2: data stored at address ra2
//  Author: <<YOUR NAME HERE>>
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

`include "../cpuglobal.vh"


module RegFile #(
    parameter DD=`COLT45_DD,
    parameter COLT45_REGWRITE=0, COLT45_REGSTALL=0
)(
    input  wire       clk,
    input  wire       we,
    input  wire[4:0]  ra1,
    input  wire[4:0]  ra2,
    input  wire[4:0]  wa,
    input  wire[31:0] wd,
    output wire[31:0] rd1,
    output wire[31:0] rd2
);

// The dist-ram is already "true dual port", using coordinated writes
//   to two banks and separate asynchronous reads.  Otherwise, we could
//   mimic this ourselves with duplicate register banks.

(* ram_style = "distributed" *) reg [31:0] R [0:31];

// Zero'th not used but seems nicer with warnings to have it.
initial R[0] = 0; // For cosmetic purposes :)

always @(posedge clk) begin
    if (wa != 5'd0) begin
        if (we) begin
            if (COLT45_REGWRITE) begin
                $display("** REG: R[%h,%d] <= %h(%d)  *WAS* %h(%d)", wa, wa, wd, wd, R[wa], R[wa]);
            end
            R[wa] <= wd;
        end else if (COLT45_REGSTALL) $display("** REG: R[%h,%d] <=** STALLed REG WRITE ** %h(%d)", wa, wa, wd, wd);
    end
end

assign #DD rd1 = (ra1 == 5'd0) ? 32'd0 : R[ra1];
assign #DD rd2 = (ra2 == 5'd0) ? 32'd0 : R[ra2];

task DUMP;
    reg [5:0] r;
    begin
        for (r=0; r < 32; r=r+1) begin
            $display("R[%h,%d] = %h(%d)", r, r, R[r], R[r]);
        end
    end
endtask

endmodule
