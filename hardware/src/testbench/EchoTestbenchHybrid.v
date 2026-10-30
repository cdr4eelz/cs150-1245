`timescale 1ns/1ps

`include "../cpuglobal.vh"

module EchoTestbenchHybrid;
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
    repeat (5) @( negedge cpu_clk_g ) ;
-> now_listening;

    // UART inputs change on falling edges of cpu_clk_g (the UART samples on
    // rising edges). Keep DataOutReady high and sample DataOutValid on falling
    // edges: a byte seen there is taken by the UART on the next rising edge.
    DataOutReady = 1;
    while (countIN < MAXCHARS) begin
        // Wait for something to come back
        @( negedge cpu_clk_g ) ;
        while (!DataOutValid) @( negedge cpu_clk_g ) ;
        countIN = countIN + 1;
-> got_something;
        $display("[%d GOT: 0x%h %b '%c' %d  @%t", countIN, DataOut, DataOut, DataOut, DataOut, $time);
    end
    $finish();
end

initial begin
    DataIn = 8'hFF;
    DataInValid = 0;

    @(now_reset); // Wait until reset completes
    $display("Xmit] Getting ready...");
    @(now_listening); // Wait until listener is listening
    @( negedge cpu_clk_g ) ;

    DataIn = 8'h7a;
    DataInValid = 1'b1;
    @( negedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (250) @( negedge cpu_clk_g );

    forever begin
        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( negedge cpu_clk_g ) ;
        DataInValid = 1'b0;
        repeat (100) @( negedge cpu_clk_g );

        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( negedge cpu_clk_g ) ;
        DataInValid = 1'b0;
        repeat (100) @( negedge cpu_clk_g );

        DataIn = DataIn+1;
        DataInValid = 1'b1;
        @( negedge cpu_clk_g ) ;
        DataInValid = 1'b0;

        @(got_something); // Wait for a char to come back
    end
end

endmodule
