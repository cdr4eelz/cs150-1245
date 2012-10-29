`include "CPUBusses.vh"

module EchoMem (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX
);
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_ShakeRx_type(8)    UARX;
    `BUS_ShakeTx_type(8)    UATX;
    // Memory busses
    wire [11: 0]    ADDR, ADDR_NEXT, ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA;
    wire [ 7: 0]    TX_Data;
    wire TX_Valid, TX_Ready, ADVANCE;

    assign TX_Valid = ~stall;
    assign ADVANCE = TX_Valid && TX_Ready;
    assign ADDR_NEXT = (ADVANCE) ? (ADDR + 1) : ADDR;
    assign ADDR_W[11:0] = { ADDR[11:2], 2'b00 };
    assign ADDR_N[1:0] = ADDR[1:0];
    assign TX_Data = DATA[ (ADDR_N*8) +: 8];
    
    PipelineRegister #( .Width(12))
    ADDR_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADVANCE ? (ADDR+1) : ADDR),
        .Out(   ADDR)
    );
    
    initial begin
        $monitor("M: %h %h %h %h %h %h",
            TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
    end
    always @(posedge clk) begin
        $strobe("C: %h %h %h %h %h %h", 
            TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
        if (ADDR > 9) $finish();
    end
    
    // Key components indirectly wired elsewhere

    dmem_blk_ram DMEM
    (   .clka(clk), .ena(1'b1), .addra(ADDR), .douta(DATA),
        .wea(4'b0000), .dina(32'd0)
    );
    
    UART uart
    (   .Clock(clk), .Reset(rst),  // Clocks of a feather
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        // Transmitter  (handshakes go both in/out)
        .DataIn(        TX_Data),
        .DataInValid(   TX_Valid),
        .DataInReady(   TX_Ready)
    );
    
    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );
    
    
endmodule
