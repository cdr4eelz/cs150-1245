`timescale 1ns/1ps

`include "CPUBusses.vh"

module DumpMEMIOTestbench;
    reg Clock, Reset, Stall;
    wire SERIAL_RX, SERIAL_TX;
    
    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun BUS_CPUGlobal
    (   ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;
    always #(HalfCycle) Clock <= ~Clock;
    
    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    DumpMEMIOCPU #( .DBG_DELAY(1) )
    CPU (   .clk(Clock), .rst(Reset), .stall(Stall),
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
    (   .CPUGlobal(CPUGlobal),
        .SERIAL_RX(SERIAL_TX), .SERIAL_TX(SERIAL_RX),
        .IOMAP(IOLISTEN)
    );
    
    integer finalcountdowneurope = 20;
    
    initial begin
        Clock = 0; Reset = 0; Stall = 0; #(2*Cycle)
        Reset = 1; #(2*Cycle)
        Addr = 0;  #(2*Cycle)
        Reset = 0; #1;
        
        //$monitor("Rx_Ready %b %b %h", iomap_listener.Rx_Ready, iomap_listener.uart.uareceive.HasByte, iomap_listener.rdata);

        while (finalcountdowneurope > 0) begin
            Addr = 12'h001;
            @(posedge Clock); @(negedge Clock);
            while (RData[0] !== 1) begin
                @(posedge Clock); @(negedge Clock);
            end
            //$display("Stat %b  %h (%d)", RData, RData, RData);
            
            Addr = 12'h003;
            @(posedge Clock); @(negedge Clock);
            $display("Got %b  %h (%d)", RData[7:0], RData[7:0], RData[7:0]);

            #1; finalcountdowneurope = finalcountdowneurope - 1;
        end
        $display("Got enough.");
        $finish();
    end

endmodule
