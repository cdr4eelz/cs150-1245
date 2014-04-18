`timescale 1ns/1ps

`include "../cpuglobal.vh"

module EchoTestbenchHybrid;
    parameter MAXCHARS  = 45; //Stop simulation upon receipt of enough chars

    parameter LITTLEWORDIAN = 1;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)

`include "echobase.vh"

    // Test log variables
    integer countIN;
    event now_listening;
    event now_reset;
    event got_something;

initial begin
    $timeformat(-9, 1, " ns", 3);
    DataOutReady = 0;
    countIN = 0;


    {rst_pll, rst_dvi_bus, rst_cpu_bus, rst_cpu_mem, rst_cpu_cpu} = 5'b11111;
    repeat (2) @( posedge user_clk_g ) ;
    rst_pll = 0;
    wait ( pll_lock ) ; // wait for pll to lock
    repeat (10) @( posedge cpu_clk_g ) ; // reset for 10 cc
    rst_cpu_mem = 0;
    wait ( init_done ) ; // wait for ddr init done
    repeat (2) @( posedge cpu_clk_g ) ;
    @( negedge cpu_clk_g ) ;
    fork
        @( posedge cpu_clk_g ) rst_cpu_bus = 0;
        @( posedge dvi_clk_g ) rst_dvi_bus = 0;
    join
    repeat (2) @( posedge cpu_clk_g ) ;
    {rst_pll, rst_dvi_bus, rst_cpu_bus, rst_cpu_mem, rst_cpu_cpu} = 0;
    repeat (30) @( posedge cpu_clk_g ) ;


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
