
    // UART (serial)
    wire FPGA_SERIAL_RX, FPGA_SERIAL_TX;
    reg   [7:0] DataIn;
    reg         DataInValid;
    wire        DataInReady;
    wire  [7:0] DataOut;
    wire        DataOutValid;
    reg         DataOutReady;
    UART #( .ClockFreq(CPU_FREQ) ) uart
    ( .Clock(cpu_clk_g), .Reset(rst_cpu_cpu),
        .SIn(FPGA_SERIAL_TX), .DataOut(DataOut),
        .DataOutReady(DataOutReady), .DataOutValid(DataOutValid),
        .DataInReady (DataInReady ), .DataInValid (DataInValid ),
        .DataIn(DataIn), .SOut(FPGA_SERIAL_RX)
    );

