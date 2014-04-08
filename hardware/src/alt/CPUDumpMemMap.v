`include "../cpuglobal.vh"

module CPUDumpMemMap #(
    parameter DD=`COLT45_DD,
    parameter ClockFreq=50_000_000,
    parameter COLT45_STEPMAX=0
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
    input frame_interrupt
);

    wire [13: 0]    ADDR, ADDR_NEXT;
    wire [11: 0]    ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W, IOSTATUS;
    wire [ 7: 0]    TX_Data;
    wire [ 1: 0]    STATE;
    wire [ 1: 0]    NEXT_STATE;

    assign #DD ADDR_W   = ADDR[13: 2];
    assign #DD ADDR_N   = ADDR[ 1: 0];
    assign #DD TX_Data  = (ADDR_N[1]) 
                ? ( (ADDR_N[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                : ( (ADDR_N[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);

    assign #DD NEXT_STATE = ((STATE === 1) && (IOSTATUS !== 32'd1)) ? STATE : (STATE+1)%4;
    assign #DD ADDR_NEXT = (STATE === 2) ? (ADDR + 1) : ADDR;

    PipelineRegister #( .Width(2) )
    ADVANCE_REG ( .clk(clk), .rst(rst), .stall(stall),
        .In(    NEXT_STATE),
        .Out(   STATE)
    );

    PipelineRegister #( .Width(14) )
    ADDR_REG ( .clk(clk), .rst(rst), .stall(stall),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );


    wire [31: 0] OUT_BRa, OUT_DB, OUT_IB;
    assign DATA_W = OUT_DB;

    // Key components indirectly wired elsewhere

    bios_mem brom_bios
    ( .clka(clk), .addra(ADDR_W),
        .ena( ~stall), .douta(OUT_BRa),
      /*.wea(4'b0000), .dina(32'b0),*/
      .clkb(clk), .addrb(12'd0),
        .enb(1'b0), .doutb()
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
    wire IRQ_TX, IRQ_RX;
    MemMapIO memmap_io
    ( .clk(clk), .rst(rst),
        .ena(~stall),
        .addra( (STATE === 2) ? 12'h002 : 12'h000 ),
        .wea  ( {3'b000, (STATE === 2)} ),
        .dina ( {24'b0, TX_Data} ),
        .DOUTA( IOSTATUS ),
        .RVa_TX (UATX),         .RVa_RX(UARX),
        .RVa_TX_IRQ(IRQ_TX),    .RVa_RX_IRQ(IRQ_RX)
    );

    UARTRVA #(
        .ClockFreq(ClockFreq)
    ) uart ( .Clock(clk), .Reset(rst),
        .SIn(FPGA_SERIAL_RX), .UARX(UARX), //Receiver
        .UATX(UATX), .SOut(FPGA_SERIAL_TX) //Transmitter
    );


// synthesis translate_off

    always@(posedge IRQ_TX or posedge IRQ_RX or negedge IRQ_TX or negedge IRQ_RX) begin
        $display("IRQ0=%b IRQ1=%b", IRQ_TX, IRQ_RX);
    end
        

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
