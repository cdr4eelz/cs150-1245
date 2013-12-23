`include "cpuglobal.vh"

module DumpMemCPU #(
    parameter ClockFreq=50_000_000,
    parameter COLT45_STEPMAX=9
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
    input [31:0] icache_dout,
    input stall,

// CP4+
    output [31:0] gp_code,
    output [31:0] gp_frame,
    output gp_valid,
    input frame_interrupt,

//BRK tap (will become internal instead)
    input brk,
    output [0:1023] trace
);

    `BUS_CPUGlobal_type CPUGlobal;
    BUS_CPUGlobal_tun TUN_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );


    wire [13: 0]    ADDR, ADDR_NEXT;
    wire [11: 0]    ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W;
    wire [ 7: 0]    TX_Data;
    wire TX_Valid, TX_Ready, ADVANCE, ADVANCE_LAST;

    assign TX_Valid = ~stall;
    assign ADVANCE  = TX_Valid && TX_Ready;
    assign ADDR_NEXT = (ADVANCE_LAST) ? (ADDR + 1) : ADDR;
    assign ADDR_W   = ADDR[13: 2];
    assign ADDR_N   = ADDR[ 1: 0];
    assign TX_Data  = (ADDR_N[1]) ? ( (ADDR_N[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                                  : ( (ADDR_N[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);

    PipelineRegister #( .Width(1) )
    ADVANCE_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADVANCE),
        .Out(   ADVANCE_LAST)
    );

    PipelineRegister #( .Width(14) )
    ADDR_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );


    wire [31: 0]    OUT_BRa, OUT_BRb, OUT_DB, OUT_IB;
    assign DATA_W = OUT_BRa;

    // Key components indirectly wired elsewhere

    bios_mem brom_bios
    ( .clka(clk),   .addra(ADDR_W),
        .ena( ~stall),      .douta(OUT_BRa),
      /*.wea(4'b0000),      .dina(32'b0),*/
      .clkb(clk),   .addrb(ADDR_W),
        .enb( 1'b1),        .doutb(OUT_BRb)
    );

    dmem_blk_ram bram_dmem
    ( .clka(clk),   .addra(ADDR_W),
        .ena( ~stall),      .douta(OUT_DB),
        .wea(4'b0000),      .dina (32'd0)
    );

    imem_blk_ram bram_imem
    ( .clka(clk),   .addra(12'b0),
        .ena(   1'b0),    /*.douta(),*/
        .wea(4'b0000),      .dina(32'b0),
      .clkb(clk),   .addrb(ADDR_W),
      /*.enb(1'b1),*/       .doutb(OUT_IB)
    );

    UART #(.ClockFreq(ClockFreq)) uart
    (   .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        // Transmitter  (handshakes go both in/out)
        .DataInReady(TX_Ready),
        .DataInValid(TX_Valid), .DataIn(TX_Data),
        // Receiver     (handshakes go both in/out)
        .DataOutReady(1'b1), // We were *born* ready!
        .DataOutValid(  ), .DataOut(  ) // ...but insolent :(
    );

// synthesis translate_off
generate if (COLT45_STEPMAX > 0) begin:_STEPS_
    initial begin
        $monitor("M: %h %h %h %h %h %h",
            TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
    end
    always @(posedge clk) begin
        if (0) $strobe("C: %b %b %h %h %h %h %h %h", 
            rst, stall, TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
        if (ADDR > COLT45_STEPMAX) $stop();
    end
end endgenerate
// synthesis translate_on

endmodule
