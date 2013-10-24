`timescale 1ns/1ps

module EchoTestbench;
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
    parameter StallRingSize = 3;
    parameter StallRingInit = 'b00000000000000000001;
    parameter StallFreq = ClockFreq * 2/3;

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

    reg [7:0] Check1, Check2, Check3, Check4, Check5, Check6, Check7;
    always @(posedge Clock)
        Check1 <= (Reset) ? 99 : Check1-1;
    always @(posedge Clock or posedge Stall)
        Check2 <= (Reset) ? 99 : Check2-1;
    always @(posedge StallClock)
        Check3 <= (Reset) ? 99 : Check3-1;
    always @(posedge Clock)
        Check4 <= (Reset) ? 99 : ((Stall) ? Check4 : Check4-1);
    wire CheckNext = (Stall) ? Check5 : Check5-1;
    always @(posedge Clock)
        Check5 <= (Reset) ? 99 : CheckNext;
    always @(posedge Clock) begin
        if (Reset) Check6 <= 99;
        else if (!Stall) Check6 <= Check6-1;
    end

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    MIPS150 CPU
    (   .clk(Clock), .rst(Reset),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
// CP2+
        .dcache_dout(32'b0), .instruction(32'b0),
// CP3+
        .filler_ready(1'b0), .line_ready(1'b0),

        .stall(Stall)
    );

    // A shadow CPU using a gated clock
    MIPS150 #(.ClockFreq(StallFreq)) xCPUx
    (   .clk(StallClock), .rst(Reset),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(xFPGA_SERIAL_TXx),
// CP2+
        .dcache_dout(32'b0), .instruction(32'b0),
// CP3+
        .filler_ready(1'b0), .line_ready(1'b0),

        .stall(1'b0)
    );
    assign serialListenTx = (1) ? FPGA_SERIAL_TX : xFPGA_SERIAL_TXx;
//  assign serialListenTx = FPGA_SERIAL_TX;

    UART          #( .ClockFreq(       ClockFreq))
                  uart( .Clock(           Clock),
                        .Reset(           Reset),
                        .DataIn(          DataIn),
                        .DataInValid(     DataInValid),
                        .DataInReady(     DataInReady),
                        .DataOut(         DataOut),
                        .DataOutValid(    DataOutValid),
                        .DataOutReady(    DataOutReady),
                        .SIn(             serialListenTx),
                        .SOut(            FPGA_SERIAL_RX));

integer count = 0, maxchars = 10;
event now_listening;
event now_reset;

initial begin
    // Reset. Has to be long enough to not be eaten by the debouncer.
    Reset = 0;
    DataOutReady = 0;
    #(100*Cycle)

    Reset = 1;
    #(30*Cycle)
    Reset = 0;
    -> now_reset;
    #(30*Cycle)

    // Wait for something to come back
    -> now_listening;
    while (count < maxchars) begin
        DataOutReady = 1; #1;
        @(posedge Clock);
        while (!DataOutValid) begin
            @(posedge Clock);
        end
        DataOutReady = 0; count = count + 1;
        $display("[%d Got %d", count, DataOut);
        #1;
    end

    $finish();
end

integer countup;
initial begin
    $display("Booting:");
    DataIn = 8'h7b;
    DataInValid = 0;
    countup = 0;

    @(now_reset);
    $display("Getting ready to send:");
    //$monitor("R:%b Ready:%b Valid:%b", Reset, DataInReady, DataInValid);
    @(now_listening);

    $display("Sending...");
    forever begin // Wait until transmit is ready
        DataInValid = 1'b1; #1;
        @(posedge Clock);
        while (!DataInReady) begin
            @(posedge Clock);
        end
        DataInValid = 1'b0; countup = countup + 1;
        $display("%d] Sent: %h %d %b", countup, DataIn, DataIn, DataIn);
        DataIn = DataIn - 1;

        #1;
    end
end

endmodule
