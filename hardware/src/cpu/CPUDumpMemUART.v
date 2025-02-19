`include "../cpuglobal.vh"

module CPUDumpMemUART #(
    parameter CPU_FREQ = 50_000_000,
    parameter BAUD_RATE =   115_200,

    parameter DD=`COLT45_DD,
    parameter COLT45_STEPMAX=9
)(
    input clk,
    input rst,
    input stall,

    // Serial
    input SerialRX,
    output SerialTX
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
    ADVANCE_REG ( .clk(clk), .rst(rst), .stall(stall),
        .In(    ADVANCE),
        .Out(   ADVANCE_LAST)
    );

    PipelineRegister #( .Width(14) )
    ADDR_REG ( .clk(clk), .rst(rst), .stall(stall),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );


    wire [31: 0]    OUT_BRa, OUT_BRb, OUT_DB, OUT_IB;
    assign DATA_W = OUT_BRa;

    // Key components indirectly wired elsewhere

    bios_mem_24 bram_bios
    (   .clk(clk),  .ena(~stall),
        .addra(ADDR_W),
        .douta(OUT_BRa),//OUT-32
        .enb(1'b1),
        .addrb(ADDR_W),
        .doutb(OUT_BRb)
    );

/*  bios_mem bram_bios
    ( .clka(clk),   .addra(ADDR_W),
        .ena( ~stall),      .douta(OUT_BRa),
      //.wea(4'b0000),      .dina(32'b0),
      .clkb(clk),   .addrb(ADDR_W),
        .enb( 1'b1),        .doutb(OUT_BRb)
    );  */

/*  dmem_blk_ram bram_dmem
    ( .clka(clk),   .addra(ADDR_W),
        .ena( ~stall),      .douta(OUT_DB),
        .wea(4'b0000),      .dina (32'd0)
    );  */

/*    imem_blk_ram bram_imem
    ( .clka(clk),   .addra(12'b0),
        .ena(   1'b0),    //.douta(),
        .wea(4'b0000),      .dina(32'b0),
      .clkb(clk),   .addrb(ADDR_W),
      //.enb(1'b1),
      .doutb(OUT_IB)
    );  */

    UART #(
        .CLOCK_FREQ(CPU_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart (  .Clock(clk),  .Reset(rst),
        .SInRX(SerialRX),  .SOutTX(SerialTX),
        // Transmitter  (handshakes go both in/out)
        .DataInReadyTX(TX_Ready),
        .DataInValidTX(TX_Valid),  .DataInTX(TX_Data),
        // Receiver     (handshakes go both in/out)
        .DataOutReadyRX(1'b1), // We were *born* ready!
        .DataOutValidRX(  ),  .DataOutRX(  ) // ...but insolent :(
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
