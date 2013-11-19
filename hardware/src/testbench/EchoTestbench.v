`timescale 1ns/1ps

`include "CPUGlobal.vh"

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

    parameter XMIT_DELAY_TICKS = 100 * Cycle, // 0 for no-delay, <0 for no-xmit
                XMIT_STALL_CYCLES = 1000;

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
//      .filler_ready(1'b0), .line_ready(1'b0),

        .stall( (1) ? Stall : 1'b0 )
    );
/*
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
*/

    UART #( .ClockFreq(ClockFreq) ) uart
    ( .Clock(Clock), .Reset(Reset),
        .DataIn(          DataIn),
        .DataInValid(     DataInValid),
        .DataInReady(     DataInReady),
        .DataOut(         DataOut),
        .DataOutValid(    DataOutValid),
        .DataOutReady(    DataOutReady),
        .SIn(             FPGA_SERIAL_TX),
//      .SIn(             (1) ? FPGA_SERIAL_TX : xFPGA_SERIAL_TXx),
        .SOut(            FPGA_SERIAL_RX)
    );

integer countIN = 0, maxchars = 10;
event now_listening;
event now_reset;

initial begin
    // Reset. Has to be long enough to not be eaten by the debouncer.
    Reset = 0;
    DataOutReady = 0;
    #(100*Cycle);

    Reset = 1;
    #(30*Cycle);
    Reset = 0;
    -> now_reset;
    #(30*Cycle);

    // Wait for something to come back
    -> now_listening;
    while (countIN < maxchars) begin
        DataOutReady = 1; #1;
        @(posedge Clock);
        while (!DataOutValid) begin
            @(posedge Clock);
        end
        DataOutReady = 0; countIN = countIN + 1;
        $display("[%d GOT: 0x%h %b '%c' %d  @%t", countIN, DataOut, DataOut, DataOut, DataOut, $time);
        #1;
    end

    $finish();
end

integer countOUT, StallCounter;
initial begin
    if (XMIT_DELAY_TICKS < 0) begin
        $display("Xmit] Disabled.");
    end else begin
        DataIn = "A";
        DataInValid = 0;
        countOUT = 0;

        @(now_reset); // Wait until reset completes
        $display("Xmit] Getting ready...");
        //$monitor("R:%b Ready:%b Valid:%b", Reset, DataInReady, DataInValid);
        @(now_listening); // Wait until listener is listening

        $display("Xmit] Delaying start of xmit...");
        #(500*Cycle);

        @(negedge Clock);
        $display("Xmit] Beginning...");
        forever begin // Wait until transmit is ready
            $display("%d] Offering: 0x%h %b '%c' %d  @%t", countOUT, DataIn, DataIn, DataIn, DataIn, $time);
            DataInValid = 1'b1;
            StallCounter = XMIT_STALL_CYCLES; // Max clock cycles to wait
            @(posedge Clock);
            while (!DataInReady) begin
                if (StallCounter > 0) begin
                    StallCounter = StallCounter - 1;
                    if (StallCounter < 0) begin
                        $display("Xmit] Stalled (STALL-CYCLES: %d  SENT-PRIOR: %d)", StallCounter, countOUT);
                    end
                end
                @(posedge Clock);
            end
            $display("%d] SENT: 0x%h %b '%c' %d  @%t", countOUT, DataIn, DataIn, DataIn, DataIn, $time);
            countOUT = countOUT + 1;
            if (XMIT_DELAY_TICKS > 0) begin
                DataInValid = 1'b0;
                #XMIT_DELAY_TICKS;
                $display("Xmit] Delay done (%d ticks)  @%t", XMIT_DELAY_TICKS, $time);
            end
            DataIn = DataIn + 1;
        end
    end
end

endmodule
