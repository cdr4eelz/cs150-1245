`timescale 1ns/1ps

`include "CPUGlobal.vh"

module RegFileTestbench;

  parameter Halfcycle = 5; //half period is 5ns

  localparam Cycle = 2*Halfcycle;

  reg Clock;

  // Clock Sinal generation:
  //initial Clock = 0; 
  //always #(Halfcycle) Clock = ~Clock;

  // Register and wires to test the RegFile
  reg [4:0] ra1;
  reg [4:0] ra2;
  reg [4:0] wa;
  reg we;
  reg [31:0] wd;
  wire [31:0] rd1;
  wire [31:0] rd2;

  RegFile DUT(.clk(Clock),
              .we(we),
              .ra1(ra1),
              .ra2(ra2),
              .wa(wa),
              .wd(wd),
              .rd1(rd1),
              .rd2(rd2));
  
  integer testnum, r;
    reg [31:0 ] testREG [0:31];
    reg [31:0 ] testVAL;
    
    task assertRegs;
      input [ 4:0 ] r1;
      input [31:0 ] v1;
      input [ 4:0 ] r2;
      input [31:0 ] v2;
      begin
          if ((r1 != ra1) || (v1 != rd1) || (r2 != ra2) || (v2 != rd2)) begin
              $display("%d. Want: R1[%d]=%h R2[%d]=%h", testnum,  r1,  v1,  r2,  v2);
              $display("%d. Got : R1[%d]=%h R2[%d]=%h", testnum, ra1, rd1, ra2, rd2);
          end
          testnum = testnum + 1;
      end
    endtask
    
  // Testing logic:
  initial begin
    testREG[0]=32'b0;
    for (r=1; r<16; r=r+1) testREG[r]=32'bx;
    testnum = 0;
    Clock = 0; ra1 = 0; ra2 = 0; wa = 0; we = 0; wd = 0;
    #1; assertRegs(0, 32'b0, 0, 32'b0);
    
    // Verify that writing to reg 0 is a nop
    #1; wd = 32'd555_555;
    #1; we = 1;
    #1; wa = 0;
    #1; ra1 = 0;
    #1; ra2 = 1;
    #1; Clock = 1;
    #1; assertRegs(0, 32'b0, 1, 32'bx);

    // Verify that data written to any other register is returned the same
    // cycle
    
    #1; ra1 = 1;
    #1; ra2 = 15;

    #1; wd = 32'd555_654;
    #1; wa = 1;
    #1; Clock = 0;
    #1; we = 1;
    #1; assertRegs(1, 32'bx, 15, 32'bx);
    #1; Clock = 1;
    #1; testREG[wa]=(wa==0)?0:wd; assertRegs(1, 32'd555_654, 15, 32'bx);
    
    #1; wd = 32'd654_654;
    #1; wa = 15;
    #1; Clock = 0;
    #1; we = 1;
    #1; assertRegs(1, 32'd555_654, 15, 32'bx);
    #1; Clock = 1;
    #1; testREG[wa]=(wa==0)?0:wd; assertRegs(1, 32'd555_654, 15, 32'd654_654);
    
    // Verify that the we pin prevents data from being written

    #1; wd = 32'd777_654;
    #1; wa = 1;
    #1; Clock = 0;
    #1; we = 0;
    #1; Clock = 1;
    #1; assertRegs(1, 32'd555_654, 15, 32'd654_654);
    
    #1; wd = 32'd777_654;
    #1; wa = 15;
    #1; Clock = 0;
    #1; we = 0;
    #1; Clock = 1;
    #1; assertRegs(1, 32'd555_654, 15, 32'd654_654);
    
    // Verify the reads are asynchronous
    for (r=0; r<16; r=r+1) begin
        ra1 = r; ra2 = 15-r;
        Clock = (r%4 == 1); // Play games with clock and ensure it doesn't interfere
        #1; assertRegs(r, testREG[r], 15-r, testREG[15-r]);
    end
    
    for (r=1; r<16; r=r+1) begin
        testVAL = {$random} & 32'hFFFFFFFF;
        Clock = 0; ra1 = 0; ra2 = 0; wa = 0; we = 0; wd = 0;
        #1; wa = r; we = 1; wd = testVAL;
        #1; Clock = 1; ra1 = r-1; ra2 = r;
        #1; testREG[r] = testVAL;
    end
    
    // Verify the things are as we expect (no need to play with clock)
    Clock = 0;
    for (r=0; r<16; r=r+1) begin
        ra1 = r; ra2 = 15-r;
        #1; assertRegs(r, testREG[r], 15-r, testREG[15-r]);
    end
    
    DUT.DUMP();
    
    $display("All tests passed! %d", testnum);
    $finish();
  end
endmodule
