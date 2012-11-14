`timescale 1ns/1ps

`include "CPUBusses.vh"

module DumpMEMIOTestbench;
    reg Clock, Reset;
    wire SERIAL_RX, SERIAL_TX;
    
    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;
    
    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;
    
    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    DumpMEMIOCPU CPU
    (   .clk(Clock), .rst(Reset), .stall(1'b0),
        .FPGA_SERIAL_RX(SERIAL_RX),
        .FPGA_SERIAL_TX(SERIAL_TX)
    );
    
    `BUS_MEMIO_type IOLISTEN;
    reg  [11:0] Addr;
    wire [31:0] RData;
    BUS_MEMIO_tun BUS_IOMAP( ._BUS_(IOLISTEN),
        .Addr   (Addr),
        .RMask  (4'b1111),      .RData  (RData),
        .WMask  (4'b0000),      .WData  (32'bz)
    );
    
    MEMIOPlex iomap_listener
    (   .clk(Clock), .rst(Reset),
        .SERIAL_RX(SERIAL_TX), .SERIAL_TX(SERIAL_RX),
        .IOMAP(IOLISTEN)
    );
    
    integer finalcountdowneurope = 20;
    
    initial begin
        Reset = 0; #(2*Cycle)
        Reset = 1; #(2*Cycle)
        Addr = 0;  #(2*Cycle)
        Reset = 0; #1;
        
        //$monitor("Rx_Ready %b %b %h", iomap_listener.Rx_Ready, iomap_listener.uart.uareceive.HasByte, iomap_listener.rdata);

        while (finalcountdowneurope > 0) begin
            Addr = 12'h001; #1
            @ (posedge Clock) #1;
            while (RData[0] !== 1) begin
                @ (posedge Clock) #1;
            end
            //$display("Stat %b  %h (%d)", RData, RData, RData);
            Addr = 12'h003; #1
            @ (posedge Clock) #1;
            
            $display("Got %b  %h (%d)", RData, RData, RData);
            #1; finalcountdowneurope = finalcountdowneurope - 1;
        end
        $display("Got enough.");
        $finish();
    end

endmodule
