`timescale 1ns/1ps

`include "../cpuglobal.vh"

module EchoTestbenchCaches;
    parameter LITTLEWORDIAN = 1;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)

`include "echobase.vh"

initial begin
    DataIn = 8'h7a;
    DataInValid = 0;
    DataOutReady = 0;

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


    repeat (5) @( posedge cpu_clk_g ) ;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h80;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h81;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);
    // Add more test cases!

    DataIn = 8'h82;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h83;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h84;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h85;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);

    DataIn = 8'h86;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    repeat (100) @( posedge cpu_clk_g );

    DataIn = 8'h87;
    DataInValid = 1'b1;
    @( posedge cpu_clk_g ) ;
    DataInValid = 1'b0;
    // Wait for something to come back
    @( posedge DataOutValid ) ;
    @( posedge cpu_clk_g ) ;
    $display("Got %h", DataOut);
    $finish();
end

endmodule
