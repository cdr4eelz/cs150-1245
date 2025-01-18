module CPUEchoDDR #(
    parameter CPU_FREQ = 50_000_000,
    parameter COLT45_SCOPE=0
)(
    input clk, rst, stall,

    // Serial
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

    // Memory system connections
    output [31:0] dcache_addr,  icache_addr,
    output [ 3:0] dcache_we,    icache_we,
    output        dcache_re,    icache_re,
    output [31:0] dcache_din,   icache_din,
    input  [31:0] dcache_dout,  icache_dout
);

    localparam ST_bits = 4;
    localparam ST_INIT = 4'b0000;
    localparam ST_RX_C = 4'b0010, ST_LOOP = ST_RX_C;
    localparam ST_RX_D = 4'b0011;
    localparam ST_WRIT = 4'b1000;
    localparam ST_TAIL = 4'b1111;
    localparam ST_RD_A = 4'b1010;
    localparam ST_RD_D = 4'b1011;
    localparam ST_TX_C = 4'b0100;
    localparam ST_TX_D = 4'b0101;
    reg [(ST_bits-1):0] state;

    reg [31: 0] cycles, stalls;
    reg [31: 0] head, tail, datum;

    wire DataOutReady = !stall && (state==ST_RX_D);
    wire [7:0] DataOut;
    wire DataOutValid;
    wire DataInReady;
    reg  [7:0] DataIn;
    wire DataInValid = !stall && (state==ST_TX_D);

    wire write_d = !stall && (state==ST_WRIT);
    assign dcache_addr = (write_d) ? head : 32'd0;
    assign dcache_we   = (write_d) ? 4'b1111 : 4'b0000;
    assign dcache_re   = 1'b0;
    assign dcache_din  = datum;
    // dcache_dout

    wire write_i = !stall && (state==ST_WRIT);
    wire read_i = !stall && (state==ST_RD_A);
    assign icache_addr = (write_i) ? head : ((read_i) ? tail : 32'd0);
    assign icache_we   = (write_i) ? 4'b1111 : 4'b0000;
    assign icache_re   = (read_i) ? 1'b1 : 1'b0;
    assign icache_din  = datum;
    // icache_dout


    initial begin
        $monitor("stall:%b head:%h tail:%h datum:%h",
                 stall, head, tail, datum);
    end

    always@(posedge clk) begin
        if (rst) begin:rst_main
            {cycles, stalls} <= 0;
            {head, tail, datum} <= 0;
            DataIn <= 0;
            state <= ST_INIT;
        end else begin
            if (!stall) case (state)
                ST_INIT: begin
                    $display("INIT.");
                    state <= ST_RX_C;
                end

                //ST_LOOP
                ST_RX_C: if (DataOutValid) begin
                    $display("RX Ready: %b %h", DataOutReady, DataOut);
                    datum <= 0;
                    state <= ST_RX_D;
                end else state <= ST_TAIL; //See if need to send
                ST_RX_D: begin
                    $display("RX: %h", DataOut);
                    datum <= {cycles[23:0], DataOut}; //Tag with cycle-count
                    state <= ST_WRIT;
                end
                ST_WRIT: begin
                    $display("Write-D: @%h <== %h", dcache_addr, datum);
                    datum <= 0;
                    head <= head + 4;
                    state <= ST_LOOP;
                end

                ST_TAIL: if (tail != head) begin
                    state <= ST_TX_C;
                end else state <= ST_LOOP; //Nothing to send, check other stuff
                ST_TX_C: if (DataInReady) begin
                    $display("TX Ready: %b %h", DataInValid, DataIn);
                    state <= ST_RD_A;
                end else state <= ST_LOOP; //Xmit busy, check other stuff
                ST_RD_A: begin
                    $display("Read-I (addr): @%h", icache_addr);
                    {datum, DataIn} <= 0;
                    state <= ST_RD_D;
                end
                ST_RD_D: begin
                    $display("Read-I (data): %h", icache_dout);
                    datum <= icache_dout;
                    DataIn <= icache_dout[7:0];
                    state <= ST_TX_D;
                end
                ST_TX_D: begin
                    $display("TX: %h", DataIn);
                    tail <= tail + 4;
                    DataIn <= 8'hE3;
                    state <= ST_LOOP;
                end

                default: begin
                    state <= ST_INIT;
                    $display("Munched invalid state");
                end
            endcase

            //Counters
            cycles   <= cycles + 1;
            stalls   <= stalls + stall;
        end
    end


    UART #(
        .ClockFreq(CPU_FREQ),
        .BaudRate(115_200)
    ) uart ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .DataOut(DataOut),
        .DataOutValid(DataOutValid), .DataOutReady(DataOutReady),
        .SOut(FPGA_SERIAL_TX), .DataIn(DataIn),
        .DataInValid(DataInValid), .DataInReady(DataInReady)
    );

endmodule
