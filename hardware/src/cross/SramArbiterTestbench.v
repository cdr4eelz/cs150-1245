`timescale 1ns/100ps
// synthesis translate_off

module SramArbiterTestbench;

    parameter CLK_PERIOD = 20; // 20 * 1ns timescale
    parameter CLK_HI = (CLK_PERIOD / 2.0); //Watchout for divisibility & precision
    parameter CLK_LO = CLK_PERIOD - (CLK_PERIOD / 2.0);
    parameter CLK_HZ = (1_000_000_000 / CLK_PERIOD);

    parameter SCREEN_WIDTH = 800, SCREEN_HEIGHT = 600;

    reg reset;
    reg clock;
    integer cycle;
    initial begin
        clock = 0;
        cycle = 0;
    end
    always begin
        #CLK_LO clock = 1;
        #CLK_HI clock = 0;
        if (clock) cycle = cycle + 1;
    end


wire        sram_addr_valid;
wire [17:0] sram_addr;
wire [31:0] sram_data_in;
wire [ 3:0] sram_write_mask;
reg  [31:0] sram_data_out = 32'bz;
reg         sram_data_out_valid = 32'b0;
reg         sram_ready = 1'b1;

integer valid_seq = 0, write_seq = 0, read_seq = 0, dead_seq = 0, wb_seq = 0;
reg  [31:0] fake_read, read_0, read_1, read_2;
always @(posedge clock) begin
    if (sram_data_out_valid) begin
        wb_seq = wb_seq + 1;
        $display("SRAM-WB:%0d D:%h", wb_seq, sram_data_out);
    end
    fake_read = 0;
    if (sram_addr_valid) begin
        valid_seq = valid_seq + 1;
        if (|sram_write_mask) begin
            write_seq = write_seq + 1;
            $display("SRAM-WR:%0d (%0d) A:%h D:%h M:%b", valid_seq, write_seq, 
                        sram_addr, sram_data_in, sram_write_mask);
            fake_read = {write_seq[11:0], 2'b11, sram_addr[17:0]};
        end else begin
            read_seq = read_seq + 1;
            $display("SRAM-RD:%0d (%0d) A:%h", valid_seq, read_seq, sram_addr);
            fake_read = {read_seq[11:0], 2'b10, sram_addr[17:0]};
        end
    end else begin
        fake_read = {dead_seq[11:0], 2'b0z, sram_addr[17:0]};
    end
    #5; sram_data_out = read_2[31:0];
    #1; sram_data_out_valid = (read_2[19:18] == 2'b10);
    read_2 = read_1;
    read_1 = read_0;
    read_0 = fake_read;
end


wire w0_clock, w1_clock, r0_clock, r1_clock;
wire w0_din_ready, w1_din_ready, r0_din_ready, r1_din_ready, r0_dout_valid, r1_dout_valid;
reg  w0_din_valid, w1_din_valid, r0_din_valid, r1_din_valid, r0_dout_ready, r1_dout_ready;
reg  [53:0] w0_din, w1_din;   // {mask-4,addr-18,data-32}
reg  [17:0] r0_din, r1_din;   // addr-18
wire [31:0] r0_dout, r1_dout; // data-32


SramArbiter dut (
    .reset(reset),
    .w0_clock(w0_clock), .w1_clock(w1_clock), .r0_clock(r0_clock), .r1_clock(r1_clock), 
    .w0_din_ready(w0_din_ready),    .w0_din_valid(w0_din_valid),    .w0_din(w0_din),
    .w1_din_ready(w1_din_ready),    .w1_din_valid(w1_din_valid),    .w1_din(w1_din),
    .r0_din_ready(r0_din_ready),    .r0_din_valid(r0_din_valid),    .r0_din(r0_din),
    .r0_dout_ready(r0_dout_ready),  .r0_dout_valid(r0_dout_valid),  .r0_dout(r0_dout),
    .r1_din_ready(r1_din_ready),    .r1_din_valid(r1_din_valid),    .r1_din(r1_din),
    .r1_dout_ready(r1_dout_ready),  .r1_dout_valid(r1_dout_valid),  .r1_dout(r1_dout),
    .sram_clock(clock),                 .sram_ready(sram_ready),
    .sram_addr_valid(sram_addr_valid),  .sram_addr(sram_addr),
    .sram_data_in(sram_data_in),        .sram_write_mask(sram_write_mask),
    .sram_data_out(sram_data_out),      .sram_data_out_valid(sram_data_out_valid)
);


module WATCHER #(
    parameter WATCH_ID = "WATCH", WID = 32
)(
    input clk, trig,
    input [WID-1:0] data
);
    integer cnt_cycle = 0, cnt_trig = 0;
    always @(posedge clk) if (reset === 0) begin
        cnt_cycle = cnt_cycle + 1;
        if (trig) begin
            cnt_trig = cnt_trig + 1;
            $display("%s:%h #%0d  @%0d", WATCH_ID, data, cnt_trig, cnt_cycle);
        end
    end
endmodule
WATCHER #("W0-REQ",54) watch_w0_req (w0_clock, w0_din_ready && w0_din_valid, w0_din);
WATCHER #("W1-REQ",54) watch_w1_req (w1_clock, w1_din_ready && w1_din_valid, w1_din);
WATCHER #("R0-REQ",18) watch_r0_req (r0_clock, r0_din_ready && r0_din_valid, r0_din);
WATCHER #("R0-RESP",32) watch_r0_resp (r0_clock, r0_dout_ready && r0_dout_valid, r0_dout);
WATCHER #("R1-REQ",18) watch_r1_req (r1_clock, r1_din_ready && r1_din_valid, r1_din);
WATCHER #("R1-RESP",32) watch_r1_resp (r1_clock, r1_dout_ready && r1_dout_valid, r1_dout);

//Some events for a little coordination
event now_reset;
initial begin:_R0_IN_
    @(now_reset);
    $display("Reset complete.");
end


integer WRITE_SEQ_w0 = 0;
wire [17:0] WRITE_NXT_w0 = {4'b1000, WRITE_SEQ_w0[13:0]};
task WRITE_w0;
begin
    while (w0_clock) #1;
    WRITE_SEQ_w0 = WRITE_SEQ_w0 + 1;
    #1; w0_din = {4'b1111, WRITE_NXT_w0, {14'd0, WRITE_NXT_w0}};
    #1; w0_din_valid = 1'b1;
    wait (w0_din_valid && w0_din_ready); @(posedge w0_clock);
    w0_din = {4'b1001, WRITE_NXT_w0, ~{14'd0, WRITE_NXT_w0}};
    #1; w0_din_valid = 1'b0;
end endtask

integer WRITE_SEQ_w1 = 0;
wire [17:0] WRITE_NXT_w1 = {4'b0100, WRITE_SEQ_w1[13:0]};
task WRITE_w1;
begin
    while (w1_clock) #1;
    WRITE_SEQ_w1 = WRITE_SEQ_w1 + 1;
    w1_din = {4'b1111, WRITE_NXT_w1, {14'd0, WRITE_NXT_w1}};
    w1_din_valid = 1'b1;
    wait (w1_din_valid && w1_din_ready); @(posedge w1_clock);
    #1; w1_din = {4'b1001, WRITE_NXT_w1, ~{14'd0, WRITE_NXT_w1}};
    #1; w1_din_valid = 1'b0;
end endtask

integer READ_SEQ_r0 = 0;
wire [17:0] READ_NXT_r0 = {4'b0010, READ_SEQ_r0[13:0]};
task READ_r0;
begin
    while (r0_clock) #1;
    READ_SEQ_r0 = READ_SEQ_r0 + 1;
    #1; r0_din = READ_NXT_r0;
    #1; r0_din_valid = 1'b1;
    wait (r0_din_valid && r0_din_ready); @(posedge r0_clock);
    #1; r0_din = ~READ_NXT_r0;
    #1; r0_din_valid = 1'b0;
end endtask

integer READ_SEQ_r1 = 0;
wire [17:0] READ_NXT_r1 = {4'b0001, READ_SEQ_r1[13:0]};
task READ_r1;
begin
    while (r1_clock) #1;
    READ_SEQ_r1 = READ_SEQ_r1 + 1;
    r1_din = READ_NXT_r1;
    r1_din_valid = 1'b1;
    wait (r1_din_valid && r1_din_ready); @(posedge r1_clock);
    r1_din = ~READ_NXT_r1;
    r1_din_valid = 1'b0;
end endtask


assign w0_clock=clock, w1_clock=clock, r0_clock=clock, r1_clock=clock;

initial begin
    #(CLK_PERIOD);
    reset = 1'b1;
    #(CLK_PERIOD);
    w0_din_valid  = 1'b0; w1_din_valid  = 1'b0;
    r0_din_valid  = 1'b0; r1_din_valid  = 1'b0;
    r0_dout_ready = 1'b0; r1_dout_ready = 1'b0;
    w0_din = {4'b0000, {5'd0, 13'h030}, 32'hE0E03030};
    w1_din = {4'b0000, {5'd0, 13'h031}, 32'hE1E13131};
    r0_din = {5'd0, 13'h0E0}; r1_din = {5'd0, 13'h0E1};
    #(CLK_PERIOD*2); while (clock) #1;
    reset = 1'b0;
    while (!w0_din_ready || !w1_din_ready || !r0_din_ready || !r1_din_ready) #1;
    while (!clock) #1; while (clock) #1;
-> now_reset;

$display("Super basic:");
    r0_dout_ready = 1'b1; r1_dout_ready = 1'b1;
    WRITE_w0; READ_r0;
    #(CLK_PERIOD * 40); while (clock) #1;

$display("Flood & clog");
    r0_dout_ready = 1'b0; r1_dout_ready = 1'b1;
    fork
        repeat (20) WRITE_w0;
        repeat (100) WRITE_w1;
        repeat (40) READ_r0; //Enough to fill up data-resp but not addr-req also
        repeat (100) READ_r1;
    join
    $display(" r0_dout_valid:%b  r1_dout_valid:%b", r0_dout_valid, r1_dout_valid);
$display("Hopefully r0-data is full but r1-data drains...");
    #(CLK_PERIOD * 140); while (clock) #1;
    $display(" r0_dout_valid:%b  r1_dout_valid:%b", r0_dout_valid, r1_dout_valid);

$display("One more request to each port...");
    fork
        WRITE_w0; WRITE_w1; READ_r0; READ_r1;
    join
    #(CLK_PERIOD * 40); while (clock) #1;
    $display(" r0_dout_valid:%b  r1_dout_valid:%b", r0_dout_valid, r1_dout_valid);

$display("Un-clog r1-data output...");
    r0_dout_ready = 1'b1; r1_dout_ready = 1'b1; //Un-clog
    #(CLK_PERIOD * 140); while (clock) #1;
    $display(" r0_dout_valid:%b  r1_dout_valid:%b", r0_dout_valid, r1_dout_valid);
    $display("How do total handled counts look after one more to all:");
    fork
        WRITE_w0; WRITE_w1; READ_r0; READ_r1;
    join
    #(CLK_PERIOD * 40); while (clock) #1;
    $display(" r0_dout_valid:%b  r1_dout_valid:%b", r0_dout_valid, r1_dout_valid);

    $stop();
end

endmodule
// synthesis translate_on
