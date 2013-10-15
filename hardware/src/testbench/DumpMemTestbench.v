`timescale 10ns/10ps

`include "CPUBusses.vh"

module DumpMemTestbench;
    reg Clock, Reset, Stall;
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;
    
    reg   [7:0] DataIn;
    reg         DataInValid;
    wire        DataInReady;
    wire  [7:0] DataOut;
    wire        DataOutValid;
    reg         DataOutReady;
    
    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;
    
    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;
    initial Stall = 0;
    always @(posedge Clock) Stall <= ~Stall;

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    DumpMemCPU CPU
    (   .clk(Clock), .rst(Reset), .stall(Stall),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
        .dcache_dout(32'b0), .instruction(32'b0),
        .filler_ready(0), .line_ready(0)

    );
    
    UART        #( .ClockFreq(       ClockFreq))
    uart_tb( .Clock(           Clock),
        .Reset(           Reset),
        .DataIn(          DataIn),
        .DataInValid(     DataInValid),
        .DataInReady(     DataInReady),
        .DataOut(         DataOut),
        .DataOutValid(    DataOutValid),
        .DataOutReady(    DataOutReady),
        .SIn(             FPGA_SERIAL_TX),
        .SOut(            FPGA_SERIAL_RX)
    );
    
    integer finalcountdowneurope = 20;
    
    initial begin
        Reset = 0; DataInValid = 0; DataOutReady = 0; #(3*Cycle)
        
        Reset = 1; #(6*Cycle)
        Reset = 0; #1;
        while (finalcountdowneurope > 0) begin
            DataOutReady = 1;
            while (DataOutReady) begin
                @ (posedge Clock) ;
                if (DataOutValid) DataOutReady = 0;
            end
            $display("Got %b  %h (%d)", DataOut, DataOut, DataOut);
            #1; finalcountdowneurope = finalcountdowneurope - 1;
        end
        $display("Got enough.");
        $finish();
    end

endmodule
