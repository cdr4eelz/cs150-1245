`include "cpuglobal.vh"

module DumpMEMIOCPU #(
    parameter ClockFreq=50_000_000,
    parameter DBG_DELAY=0, COLT45_STEPMAX=0
)(
    input clk,
    input rst,

    // Serial
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

// CP2+
    // Memory system connections
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output [3:0] icache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    output [31:0] icache_din,
    input [31:0] dcache_dout,
    input [31:0] instruction,

// CP3+
    output [31:0] bypass_addr,
    output [31:0] bypass_din,
    output [3:0]  bypass_we,
    // Graphics ports
    input          filler_ready,
    input          line_ready,
    output  [23:0] filler_color,
    output         filler_valid,
    output  [31:0] line_color,
    output  [9:0]  line_point,
    output         line_color_valid,
    output         line_x0_valid,
    output         line_y0_valid,
    output         line_x1_valid,
    output         line_y1_valid,
    output         line_trigger,

    input stall
);

    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun TUN_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

    wire [13: 0]    ADDR, ADDR_NEXT;
    wire [11: 0]    ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W, IOSTATUS;
    wire [ 7: 0]    TX_Data;
    wire [ 1: 0]    STATE;
    wire [ 1: 0]    NEXT_STATE;

    assign #DBG_DELAY ADDR_W   = ADDR[13: 2];
    assign #DBG_DELAY ADDR_N   = ADDR[ 1: 0];
    assign #DBG_DELAY TX_Data  = (ADDR_N[1]) 
                ? ( (ADDR_N[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                : ( (ADDR_N[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);

    assign #DBG_DELAY NEXT_STATE = ((STATE === 1) && (IOSTATUS !== 32'd1)) ? STATE : (STATE+1)%4;
    assign #DBG_DELAY ADDR_NEXT = (STATE === 2) ? (ADDR + 1) : ADDR;

    PipelineRegister #( .Width(2) )
    ADVANCE_REG ( .CPUGlobal(CPUGlobal),
        .In(    NEXT_STATE),
        .Out(   STATE)
    );

    PipelineRegister #( .Width(14) )
    ADDR_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );


    wire [31: 0] OUT_BRa, OUT_BRb, OUT_DB, OUT_IB;
    assign DATA_W = OUT_DB;

    // Key components indirectly wired elsewhere

    bios_mem brom_bios
    ( .clka(clk), .addra(ADDR_W),
        .ena( ~stall), .douta(OUT_BRa),
      /*.wea(4'b0000), .dina(32'b0),*/
      .clkb(clk), .addrb(ADDR_W),
        .enb( ~stall), .doutb(OUT_BRb)
    );

    dmem_blk_ram bram_dmem
    ( .clka(clk), .addra(ADDR_W),
        .ena( ~stall), .douta(OUT_DB),
        .wea(4'b0000), .dina (32'd0)
    );

    imem_blk_ram bram_imem
    ( .clka(clk), .addra(12'b0),
        .ena(   1'b0), /*.douta(),*/
        .wea(4'b0000), .dina(32'b0),
      .clkb(clk), .addrb(ADDR_W),
      /*.enb(1'b1),*/ .doutb(OUT_IB)
    );

    `BUS_SHAKE_type(8)  UATX, UARX;
    MEMIOPlex iomap_uart
    ( .clk(clk), .rst(rst), .ena(~stall),
        .addra( (STATE === 2) ? 12'h002 : 12'h000 ),
        .wea  ( {3'b000, (STATE === 2)} ),
        .dina ( {24'b0, TX_Data} ),
//      .rmask( {3'b000, (STATE !== 2)} ),
        .douta( IOSTATUS ),
        .RVA_TX (UATX), .RVA_RX(UARX)
    );

    //TODO: Use UART wrapper that takes two RVA's
    wire Rx_Ready, Rx_Valid, Tx_Valid, Tx_Ready;
    wire [7:0] Rx_Data, Tx_Data;
    BUS_SHAKE_tun #(.InWidth(8)) TUN_SHAKE_Rx
    ( ._BUS_(UARX),
        .DataReady(Rx_Ready),
        .DataValid(Rx_Valid), .Data(Rx_Data)
    );
    BUS_SHAKE_tap #(.InWidth(8)) TAP_SHAKE_Tx
    ( ._BUS_(UATX),
        .DataValid(Tx_Valid), .Data(Tx_Data),
        .DataReady(Tx_Ready)
    );
    UART #(.ClockFreq(ClockFreq)) uart
    ( .Clock(clk), .Reset(rst),
        // Receiver     (handshakes go both in/out)
        .SIn(FPGA_SERIAL_RX),
        .DataOut(Rx_Data), .DataOutValid(Rx_Valid), .DataOutReady(Rx_Ready),
        // Transmitter  (handshakes go both in/out)
        .SOut(FPGA_SERIAL_TX),
        .DataIn(Tx_Data), .DataInValid(Tx_Valid), .DataInReady(Tx_Ready)
    );


// synthesis translate_off
generate if (COLT45_STEPMAX > 0) begin:_STEPS_
    integer DBG_CNT = 0;
    always@(posedge clk) begin
        $display("CNT=%d, R=%b, Next=%d, State=%d", DBG_CNT, rst, NEXT_STATE, STATE);
        $display("Addr=%h, Data=%h, Status=%h", ADDR, TX_Data, IOSTATUS);
        DBG_CNT = DBG_CNT + 1;
        if (DBG_CNT >= COLT45_STEPMAX) $stop();
    end
end endgenerate
// synthesis translate_on

endmodule
