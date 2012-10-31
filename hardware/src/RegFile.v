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

module RegFile(input         clk,
               input         we,
               input  [4:0]  ra1,
               input  [4:0]  ra2,
               input  [4:0]  wa,
               input  [31:0] wd,
               output [31:0] rd1,
               output [31:0] rd2);
    
// The dist-ram is already "true dual port", using coordinated writes
//   to two banks and separate asynchronous reads.  Otherwise, we could
//   mimic this ourselves with duplicate register banks.
    
    (* ram_style = "distributed" *) reg [31:0] R [31:0]; // Zero'th not used
    
    always @(posedge clk) begin
        if (we && (wa != 5'd0)) begin
            $display("*STORE* REG: R[%h,%d] <= %h(%d)  *WAS* %h(%d)", wa, wa, wd, wd, R[wa], R[wa]);
            R[wa] <= wd;
        end
    end
    
	assign rd1 = (ra1 == 5'd0) ? 32'd0 : R[ra1];
	assign rd2 = (ra2 == 5'd0) ? 32'd0 : R[ra2];
endmodule
