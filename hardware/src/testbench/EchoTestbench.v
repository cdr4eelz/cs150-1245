`timescale 1ns/1ps

module EchoTestbench;

    reg Clock, Reset;
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

    // Instantiate your CPU here and connect the FPGA_SERIAL_TX wires
    // to the UART we use for testing
    MIPS150 CPU
    (   .clk(Clock), .rst(Reset), .stall(1'b0),
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX)
    );

    UART          #( .ClockFreq(       ClockFreq))
                  uart( .Clock(           Clock),
                        .Reset(           Reset),
                        .DataIn(          DataIn),
                        .DataInValid(     DataInValid),
                        .DataInReady(     DataInReady),
                        .DataOut(         DataOut),
                        .DataOutValid(    DataOutValid),
                        .DataOutReady(    DataOutReady),
                        .SIn(             FPGA_SERIAL_TX),
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
          $display("%d] Got %d", count, DataOut);
	  #1;
      end

      $finish();
  end

integer countup;
  initial begin
      $display("Booting test");
      DataIn = 8'h7a;
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
