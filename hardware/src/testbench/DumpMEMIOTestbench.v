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
    parameter StallRingSize = 3;
    parameter StallRingInit = 'b00000000000000000001;

    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;

//    always @(posedge Clock) Stall <= ~Stall;
    reg [StallRingSize-1:0] StallRing;
//    initial begin StallRing = 0; Stall = 0; end
    always @(posedge Clock) begin
        if (Reset) begin
            StallRing <= StallRingInit;
        end else begin
            StallRing <= {StallRing[StallRingSize-2:0], StallRing[StallRingSize-1]};
        end
        Stall <= StallRing[StallRingSize-1];
    end
    wire StallClock = Clock || Stall; // Gated clock for reference/cheating


    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    DumpMEMIOCPU CPU
//  (   .clk(StallClock), .rst(Reset), .stall(1'b0),
    (   .clk(Clock), .rst(Reset), .stall(Stall),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
// CP2+
        .dcache_dout(32'b0), .instruction(32'b0),
// CP3+
        .filler_ready(1'b0), .line_ready(1'b0)
    );

    UART        #( .ClockFreq(       ClockFreq))
    uart_tb( .Clock(      Clock),
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
        $stop();
    end

/*
    $monitor("Rx_Ready %b %b %h", iomap_listener.Rx_Ready, iomap_listener.uart.uareceive.HasByte, iomap_listener.rdata);

    reg  [11:0] Addr;
    wire [31:0] RData;
    `BUS_MMAP_type IOLISTEN;
    BUS_MMAP_tun BUS_IOMAP( ._BUS_(IOLISTEN),
        .Addr   (Addr),
        .RMask  (4'b1111),      .RData  (RData),
        .WMask  (4'b0000),      .WData  (32'bz)
    );

    MEMIOPlex iomap_listener
    (   .clk(Clock), .rst(Reset), .ena(~Stall),
        .SERIAL_RX(SERIAL_TX), .SERIAL_TX(SERIAL_RX),
        .IOMAP(IOLISTEN)
    );
*/

endmodule
