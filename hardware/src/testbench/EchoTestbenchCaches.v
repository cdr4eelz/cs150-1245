`timescale 1ns/1ps

`include "../cpuglobal.vh"

module EchoTestbenchCaches;
    parameter LITTLEWORDIAN = 1;
    parameter CPU_FREQ  = 50_000_000; //CPU-clock
    parameter HalfCycle = 5; //USER-clock 100MHz (half-period)
    parameter CPU_CORE = "";
`include "base_clock.vh"
`include "base_mem.vh"
`include "base_echo.vh"
`include "base_mips.vh"

initial begin
    DataIn = 8'h7a;
    DataInValid = 0;
    DataOutReady = 0;

BaseClockReset();

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
