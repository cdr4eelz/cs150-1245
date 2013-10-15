`timescale 10ns/10ps

`include "CPUBusses.vh"

module DumpMEMIOTestbench;
    reg Clock, Reset, Stall;
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;
    
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun BUS_CPUGlobal
    (   ._BUS_(CPUGlobal),
        .CLK(Clock), .RST(Reset), .STL(Stall)
    );

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
    DumpMEMIOCPU CPU
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

/*
        $monitor("Rx_Ready %b %b %h", iomap_listener.Rx_Ready, iomap_listener.uart.uareceive.HasByte, iomap_listener.rdata);

    `BUS_MEMIO_type IOLISTEN;
    reg  [11:0] Addr;
    wire [31:0] RData;
    BUS_MEMIO_tun BUS_IOMAP( ._BUS_(IOLISTEN),
        .Addr   (Addr),
        .RMask  (4'b1111),      .RData  (RData),
        .WMask  (4'b0000),      .WData  (32'bz)
    );
    
    MEMIOPlex iomap_listener
    (   .CPUGlobal(CPUGlobal),
        .SERIAL_RX(SERIAL_TX), .SERIAL_TX(SERIAL_RX),
        .IOMAP(IOLISTEN)
    );
*/
    
endmodule
