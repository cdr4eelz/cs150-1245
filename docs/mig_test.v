module skoll_ddr3 (
 input clk_in,

// DDR3 Physical Interface Signals
 //Inouts
 inout  [15:0] ddr3_dq,
 inout  [1:0]  ddr3_dqs_n,
 inout  [1:0]  ddr3_dqs_p,
 // Outputs
 output [13:0] ddr3_addr,
 output [2:0]  ddr3_ba,
 output ddr3_ras_n,
 output ddr3_cas_n,
 output ddr3_we_n,
 output ddr3_reset_n,
 output [0:0] ddr3_ck_p,
 output [0:0] ddr3_ck_n,
 output [0:0] ddr3_cke,
 output [0:0] ddr3_cs_n,
 output [1:0] ddr3_dm,
 output [0:0] ddr3_odt,

// LEDs to signal pass/fail
 output reg  led_pass,
 output reg  led_fail,
 output wire led_calib
 );

 wire calib_done;

 reg  [27:0] app_addr = 0;
 reg  [2:0]  app_cmd = 0;
 reg  app_en;
 wire app_rdy;

 reg  [127:0] app_wdf_data;
 wire app_wdf_end = 1;
 reg  app_wdf_wren;
 wire app_wdf_rdy;

 wire [127:0] app_rd_data;
 wire [15:0] app_wdf_mask = 0;
 wire app_rd_data_end;
 wire app_rd_data_valid;

 wire app_sr_req = 0;
 wire app_ref_req = 0;
 wire app_zq_req = 0;
 wire app_sr_active;
 wire app_ref_ack;
 wire app_zq_ack;

 wire ui_clk;
 wire ui_clk_sync_rst;

 wire sys_clk_i;

 reg [127:0] data_to_write = {32'hcafebabe, 32'h12345678,
                              32'hAA55AA55, 32'h55AA55AA};
 reg [127:0] data_read_from_memory = 128'd0;

 // Power-on-reset generator circuit.
 // Asserts resetn for 1023 cycles, then deasserts
 // `resetn` is Active low reset
 reg [9:0] por_counter = 1023;
 always @ (posedge clk_in) begin
   if (por_counter) begin
     por_counter <= por_counter - 1 ;
   end
 end

 wire resetn = (por_counter == 0);

 // Clock Wizard
 // DDR3 core requires 200MHz input clock
 // We generate this clock using Xilinx Clocking Wizard IP Core
 clk_wiz clk_wiz (
   .clk_in (clk_in),
   .clk_200 (sys_clk_i),
   .resetn (resetn)
 );

// Instatiation of MIG core named `mem`
 mem mem (
   // DDR3 Physical interface ports
   .ddr3_addr   (ddr3_addr),
   .ddr3_ba     (ddr3_ba),
   .ddr3_cas_n  (ddr3_cas_n),
   .ddr3_ck_n   (ddr3_ck_n),
   .ddr3_ck_p   (ddr3_ck_p),
   .ddr3_cke    (ddr3_cke),
   .ddr3_ras_n  (ddr3_ras_n),
   .ddr3_reset_n(ddr3_reset_n),
   .ddr3_we_n   (ddr3_we_n),
   .ddr3_dq     (ddr3_dq),
   .ddr3_dqs_n  (ddr3_dqs_n),
   .ddr3_dqs_p  (ddr3_dqs_p),
   .ddr3_cs_n   (ddr3_cs_n),
   .ddr3_dm     (ddr3_dm),
   .ddr3_odt    (ddr3_odt),

   .init_calib_complete (calib_done),

   // User interface ports
   .app_addr    (app_addr),
   .app_cmd     (app_cmd),
   .app_en      (app_en),
   .app_wdf_data(app_wdf_data),
   .app_wdf_end (app_wdf_end),
   .app_wdf_wren(app_wdf_wren),
   .app_rd_data (app_rd_data),
   .app_rd_data_end (app_rd_data_end),
   .app_rd_data_valid (app_rd_data_valid),
   .app_rdy     (app_rdy),
   .app_wdf_rdy (app_wdf_rdy),
   .app_sr_req  (app_sr_req),
   .app_ref_req (app_ref_req),
   .app_zq_req  (app_zq_req),
   .app_sr_active(app_sr_active),
   .app_ref_ack (app_ref_ack),
   .app_zq_ack  (app_zq_ack),
   .ui_clk      (ui_clk),
   .ui_clk_sync_rst (ui_clk_sync_rst),
   .app_wdf_mask(app_wdf_mask),
   // Clock and Reset input ports
   .sys_clk_i (sys_clk_i),
   .sys_rst (resetn)
   );

 localparam IDLE = 3'd0;
 localparam WRITE = 3'd1;
 localparam WRITE_DONE = 3'd2;
 localparam READ = 3'd3;
 localparam READ_DONE = 3'd4;
 localparam PARK = 3'd5;
 reg [2:0] state = IDLE;

 localparam CMD_WRITE = 3'b000;
 localparam CMD_READ = 3'b001;

 assign led_calib = calib_done;

always @ (posedge ui_clk) begin
  if (ui_clk_sync_rst) begin
    state <= IDLE;
    app_en <= 0;
    app_wdf_wren <= 0;
  end else begin
    case (state)
      IDLE: begin
        if (calib_done) begin
          state <= WRITE;
        end
      end

      WRITE: begin
        if (app_rdy & app_wdf_rdy) begin
          state <= WRITE_DONE;
          app_en <= 1;
          app_wdf_wren <= 1;
          app_addr <= 0;
          app_cmd <= CMD_WRITE;
          app_wdf_data <= data_to_write;
        end
      end

      WRITE_DONE: begin
        if (app_rdy & app_en) begin
          app_en <= 0;
        end

        if (app_wdf_rdy & app_wdf_wren) begin
          app_wdf_wren <= 0;
        end

        if (~app_en & ~app_wdf_wren) begin
          state <= READ;
        end
      end

      READ: begin
        if (app_rdy) begin
          app_en <= 1;
          app_addr <= 0;
          app_cmd <= CMD_READ;
          state <= READ_DONE;
        end
      end

      READ_DONE: begin
        if (app_rdy & app_en) begin
          app_en <= 0;
        end

        if (app_rd_data_valid) begin
          data_read_from_memory <= app_rd_data;
          state <= PARK;
        end
      end

      PARK: begin
        if (data_to_write == data_read_from_memory) begin
          led_pass <= 1;
        end else if (data_to_write != data_read_from_memory) begin
          led_fail <= 1;
        end
      end

      default: state <= IDLE;
   endcase
 end
end

endmodule // top

