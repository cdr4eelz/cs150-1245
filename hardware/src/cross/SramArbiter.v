module SramArbiter(
  // Application interface
  input reset,

  // W0
  input         w0_clock,
  output        w0_din_ready,
  input         w0_din_valid,
  input [53:0]  w0_din,// {mask-4,addr-18,data-32}

  // W1
  input         w1_clock,
  output        w1_din_ready,
  input         w1_din_valid,
  input [53:0]  w1_din,// {mask-4,addr-18,data-32}

  // R0
  input         r0_clock,
  output        r0_din_ready,
  input         r0_din_valid,
  input  [17:0] r0_din, // addr-18
  input         r0_dout_ready,
  output        r0_dout_valid,
  output [31:0] r0_dout, // data-32

  // R1
  input         r1_clock,
  output        r1_din_ready,
  input         r1_din_valid,
  input  [17:0] r1_din, // addr-18
  input         r1_dout_ready,
  output        r1_dout_valid,
  output [31:0] r1_dout, // data-32

  // SRAM Interface
  input         sram_clock,
  output        sram_addr_valid,
  input         sram_ready,
  output [17:0] sram_addr,
  output [31:0] sram_data_in,
  output  [3:0] sram_write_mask,
  input  [31:0] sram_data_out,
  input         sram_data_out_valid
);


// Arbiter Params, Signals & Data ----------------------------------------------

localparam SERV_NONE    = 4'b0000;
localparam SERV_W0      = 4'b1000;
localparam SERV_W1      = 4'b0100;
localparam SERV_R0      = 4'b0010;
localparam SERV_R1      = 4'b0001;
localparam SERV_WRITE   = SERV_W0 | SERV_W1;
localparam SERV_READ    = SERV_R0 | SERV_R1;

// From FIFOs
wire sw0_dout_valid, sw1_dout_valid, sa0_dout_valid, sa1_dout_valid;
wire [53:0] sw0_dout, sw1_dout;   // WRITE: {mask,addr,data}
wire [17:0] sa0_dout, sa1_dout;   // READ-REQ: addr
wire sd0_fullish, sd1_fullish;

// To FIFOs
wire sd0_din_en, sd1_din_en;
wire [31:0] sd0_din, sd1_din;    // READ-RESP: data
wire sw0_dout_en, sw1_dout_en, sa0_dout_en, sa1_dout_en;

// Arbiter Logic ---------------------------------------------------------------


reg  [3:0] serv_robin;
reg  [3:0] serv_0, serv_1, serv_2, serv_3; //Brief history for write-back (or debug)
wire [3:0] serv_want, serv_can, serv_avail;
reg  [3:0] serv_next;

assign serv_want = {sw0_dout_valid, sw1_dout_valid, sa0_dout_valid, sa1_dout_valid};
assign serv_can  = {1'b1,           1'b1,           ~sd0_fullish,   ~sd1_fullish};
assign             {sw0_dout_en,    sw1_dout_en,    sa0_dout_en,    sa1_dout_en} = serv_next;
assign serv_avail = serv_want & serv_can & {4{sram_ready}};
//assign serv_next = serv_robin & serv_avail; //Non-skipping robin

always @(*) begin
    serv_next = SERV_NONE;
    case (serv_robin)
        default: casex (serv_avail)
                4'b1xxx: serv_next = 4'b1000;
                4'b01xx: serv_next = 4'b0100;
                4'b001x: serv_next = 4'b0010;
                4'b0001: serv_next = 4'b0001;
            endcase
        4'b0100: casex (serv_avail)
                4'bx1xx: serv_next = 4'b0100;
                4'bx01x: serv_next = 4'b0010;
                4'bx001: serv_next = 4'b0001;
                4'b1000: serv_next = 4'b1000;
            endcase
        4'b0010: casex (serv_avail)
                4'bxx1x: serv_next = 4'b0010;
                4'bxx01: serv_next = 4'b0001;
                4'b1x00: serv_next = 4'b1000;
                4'b0100: serv_next = 4'b0100;
            endcase
        4'b0001: casex (serv_avail)
                4'bxxx1: serv_next = 4'b0001;
                4'b1xx0: serv_next = 4'b1000;
                4'b01x0: serv_next = 4'b0100;
                4'b0010: serv_next = 4'b0010;
            endcase
    endcase
end

always @(posedge sram_clock) begin
    if (reset) begin
        serv_robin <= SERV_W0;
        {serv_0, serv_1, serv_2, serv_3} <= 0;
    end else begin
        if (|serv_next) serv_robin <= {serv_next[0], serv_next[3:1]};
        else serv_robin <= {serv_robin[0], serv_robin[3:1]}; //Could make custom sequencer FSM/Lookup
        {serv_0, serv_1, serv_2, serv_3} <= {serv_next, serv_0, serv_1, serv_2};
    end
end

reg [(1+(4+18+32))-1:0] drive_thru;
always @(*) begin:_DRIVETHRU_MUX_
    case (serv_next) //       {valid, mask,        addr,  data }
        default: drive_thru = { 1'b0, 4'b0000,    18'd0, 32'd0 };
        SERV_W0: drive_thru = { 1'b1, sw0_dout /* pre-cat'd */ };
        SERV_W1: drive_thru = { 1'b1, sw1_dout /* pre-cat'd */ };
        SERV_R0: drive_thru = { 1'b1, 4'b0000, sa0_dout, 32'd0 };
        SERV_R1: drive_thru = { 1'b1, 4'b0000, sa1_dout, 32'd0 };
    endcase
end
assign {sram_addr_valid, sram_write_mask, sram_addr, sram_data_in} = drive_thru;


// Drive write-back at right bat-time to right bat-place
assign sd0_din = sram_data_out, sd0_din_en = |(serv_3 & SERV_R0);
assign sd1_din = sram_data_out, sd1_din_en = |(serv_3 & SERV_R1);
// And notice any obviously mistimed  writeback
wire fault_read_miss = !sram_data_out_valid && |(serv_3 & SERV_READ);
wire fault_read_xtra = sram_data_out_valid && |(serv_3 & ~SERV_READ);


// Helper & translations -------------------------------------------------------

wire w0_full, w1_full, r0_full, r1_full;
wire w0_din_shake, w1_din_shake, r0_din_shake, r1_din_shake, r0_dout_shake, r1_dout_shake;

// Translations to RVA style port names (ready == !full)
assign w0_din_ready = !w0_full,     w1_din_ready = !w1_full;
assign r0_din_ready = !r0_full,     r1_din_ready = !r1_full;

// First-word-fallthru makes these just like RVA handshakes (name signals for debug output)
assign w0_din_shake  = w0_din_ready  && w0_din_valid,  w1_din_shake  = w1_din_ready  && w1_din_valid;
assign r0_din_shake  = r0_din_ready  && r0_din_valid,  r1_din_shake  = r1_din_ready  && r1_din_valid;
assign r0_dout_shake = r0_dout_ready && r0_dout_valid, r1_dout_shake = r1_dout_ready && r1_dout_valid;

// Debug/monitor signals
wire w0_over, w1_over, r0_over, r1_over, sd0_over, sd1_over;
wire sw0_under, sw1_under, sa0_under, r0_under, sa1_under, r1_under;
wire [5:0] r0_count, sd0_count, r1_count, sd1_count;
reg  fault_sdram, fault_w0, fault_w1, fault_r0, fault_r1; // Persistent per-clock region
reg  fault_extern; // w0|w1|r0|r1 sync'd to sdram-clock
wire fault_any = fault_sdram | fault_extern | fault_read_miss | fault_read_xtra;

// synthesis translate_off
always @(posedge sram_clock) begin
    if (!reset && |serv_avail) begin
        $display("AVAIL:%b ROBIN:%b NEXT:%b  (%0d|%0d) FAULT:%b",
            serv_avail, serv_robin, serv_next, sd0_count, sd1_count, fault_any);
    end
end
// synthesis translate_on


// Clock crossing FIFOs --------------------------------------------------------

SRAM_WRITE_FIFO sw0_fifo(
  .rst(reset),
  .wr_clk(w0_clock),
  .wr_en(   w0_din_shake   ),
  .din(     w0_din         ), //IN-54
  .full(    w0_full        ), //OUT
  .rd_clk(sram_clock),
  .rd_en(   sw0_dout_en    ),
  .valid(   sw0_dout_valid ), //OUT
  .dout(    sw0_dout       ), //OUT-54: {mask-4,addr-18,data-32}
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(w0_over), .underflow(sw0_under) //OUT
);

SRAM_WRITE_FIFO sw1_fifo(
  .rst(reset),
  .wr_clk(w1_clock),
  .wr_en(   w1_din_shake   ),
  .din(     w1_din         ),
  .full(    w1_full        ), //OUT
  .rd_clk(sram_clock),
  .rd_en(   sw1_dout_en    ),
  .valid(   sw1_dout_valid ), //OUT
  .dout(    sw1_dout       ), //OUT-54: {mask-4,addr-18,data-32}
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(w1_over), .underflow(w1_under) //OUT
);


SRAM_ADDR_FIFO sa0_fifo(
  .rst(reset),
  .wr_clk(r0_clock),
  .wr_en(   r0_din_shake   ),
  .din(     r0_din         ),
  .full(    r0_full        ), //OUT
  .rd_clk(sram_clock),
  .rd_en(   sa0_dout_en    ),
  .valid(   sa0_dout_valid ), //OUT
  .dout(    sa0_dout       ), //OUT-18: addr
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(r0_over), .underflow(sa0_under) //OUT
);

SRAM_DATA_FIFO sd0_fifo(
  .rst(reset),
  .wr_clk(sram_clock),
  .wr_en(   sd0_din_en     ),
  .din(     sd0_din        ),
  .full(                   ), //OUT
  .prog_full( sd0_fullish  ), //OUT
  .rd_clk(r0_clock),
  .rd_en(   r0_dout_shake  ),
  .valid(   r0_dout_valid  ), //OUT
  .dout(    r0_dout        ), //OUT-32: data
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(sd0_over), .underflow(r0_under), //OUT
  .prog_full_thresh( 5'd25 ), //IN-5
  .rd_data_count(r0_count), .wr_data_count(sd0_count) //OUT-6
);


SRAM_ADDR_FIFO sa1_fifo(
  .rst(reset),
  .wr_clk(r1_clock),
  .wr_en(   r1_din_shake   ),
  .din(     r1_din         ),
  .full(    r1_full        ), //OUT
  .rd_clk(sram_clock),
  .rd_en(   sa1_dout_en    ),
  .valid(   sa1_dout_valid ), //OUT
  .dout(    sa1_dout       ), //OUT-18: addr
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(r1_over), .underflow(sa1_under) //OUT
);

SRAM_DATA_FIFO sd1_fifo(
  .rst(reset),
  .wr_clk(sram_clock),
  .wr_en(   sd1_din_en     ),
  .din(     sd1_din        ),
  .full(                   ), //OUT
  .prog_full( sd1_fullish  ), //OUT
  .rd_clk(r1_clock),
  .rd_en(   r1_dout_shake  ),
  .valid(   r1_dout_valid  ), //OUT
  .dout(    r1_dout        ), //OUT-32: data
  .empty(                  ), //OUT
//Debug/monitor signals
  .overflow(sd1_over), .underflow(r1_under), //OUT
  .prog_full_thresh( 5'd25 ), //IN-5
  .rd_data_count(r1_count), .wr_data_count(sd1_count) //OUT-6
);


// Persistent fault flags per-clock region & gathered to sdram clock
always @(posedge sram_clock)
    if (reset) begin
        fault_sdram <= 0;
        fault_extern <= 0;
    end else begin
        if (sw0_under || w1_under || sa0_under || sa1_under
            || sd0_over || sd1_over) fault_sdram <= 1;
        if (fault_w0 || fault_w1 || fault_r0 || fault_r1) fault_extern <= 1;
    end
always @(posedge w0_clock)
    if (reset) fault_w0 <= 0;
    else if (w0_over) fault_w0 <= 1;
always @(posedge w1_clock)
    if (reset) fault_w1 <= 0;
    else if (w1_over) fault_w1 <= 1;
always @(posedge r0_clock)
    if (reset) fault_r0 <= 0;
    else if (r0_over || r0_under) fault_r0 <= 1;
always @(posedge r1_clock)
    if (reset) fault_r1 <= 0;
    else if (r1_over || r1_under) fault_r1 <= 1;

endmodule
