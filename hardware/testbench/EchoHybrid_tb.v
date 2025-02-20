`timescale 1ns/1ps

`include "../src/cpuglobal.vh"

module EchoHybrid_tb;
    parameter LITTLEWORDIAN = 1;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)
    parameter CPU_CORE = "";
`include "base_clock.vh"
`include "base_mem.vh"
`include "base_echo.vh"
`include "base_mips.vh"

    parameter MAXCHARS  = 45; //Stop simulation upon receipt of enough chars

    // Test log variables
    integer countIN;
    event now_listening;
    event now_reset;
    event got_something;

initial begin
    $timeformat(-9, 1, " ns", 3);
    DataOutReady = 0;
    countIN = 0;

BaseClockReset();


    // Wait until transmit is ready
-> now_reset;
    repeat (5) @( posedge cpu_clk_g ) ;
-> now_listening;

    while (countIN < MAXCHARS) begin
        DataOutReady = 1; #1;
        // Wait for something to come back
        @( posedge DataOutValid ) ;
        @( posedge cpu_clk_g ) ;
//      @(posedge cpu_clk_g);
//      while (!DataOutValid) begin
//          @(posedge cpu_clk_g);
//      end
        DataOutReady = 0; countIN = countIN + 1;
-> got_something;
        $display("[%d GOT: 0x%h %b '%c' %d  @%t", countIN, DataOut, DataOut, DataOut, DataOut, $time);
        #1;
    end
    $finish();
end

initial begin
    DataIn = 8'hFF;
    DataInValid = 0;

    @(now_reset); // Wait until reset completes
    $display("Xmit] Getting ready...");
    @(now_listening); // Wait until listener is listening
    @(negedge USER_CLK);

    DataIn = 8'h7a;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (250) @( posedge cpu_clk_g );

    forever begin
        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( posedge cpu_clk_g ) ;
        DataInValid = 1'b0;
        repeat (100) @( posedge cpu_clk_g );

        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( posedge cpu_clk_g ) ;
        DataInValid = 1'b0;
        repeat (100) @( posedge cpu_clk_g );

        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( posedge cpu_clk_g ) ;
        DataInValid = 1'b0;

        @(got_something); // Wait for a char to come back
    end
end

endmodule
