`include "CPUBusses.vh"

module DumpMemCPU (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX
);
    wire stl = stall; // Just friendly rename
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_ShakeRx_type(8)    UARX;
    `BUS_ShakeTx_type(8)    UATX;
    
    wire [11: 0]    ADDR, ADDR_NEXT, ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W;
    wire [ 7: 0]    TX_Data;
    wire TX_Valid, TX_Ready, ADVANCE, ADVANCE_LAST;
    
    assign TX_Valid = !stl;
    assign ADVANCE = TX_Valid && TX_Ready;
    assign ADDR_NEXT = (ADVANCE_LAST) ? (ADDR + 1) : ADDR;
    assign ADDR_W = (ADDR / 4);
    assign ADDR_N = (ADDR % 4);
    assign TX_Data = (ADDR[1])  ? ( (ADDR[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                                : ( (ADDR[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);
    
    PipelineRegister #( .Width(1) )
    ADVANCE_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADVANCE),
        .Out(   ADVANCE_LAST)
    );
    
    PipelineRegister #( .Width(12) )
    ADDR_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );
    
    `ifdef SIM
    initial begin
        $monitor("M: %h %h %h %h %h %h",
            TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
    end
    always @(posedge clk) begin
//        $strobe("C: %h %h %h %h %h %h", 
//            TX_Ready, ADVANCE, ADDR, ADDR_W, ADDR_N, TX_Data);
        if (ADDR > 9) $finish();
    end
    `endif
    
    // Key components indirectly wired elsewhere

    dmem_blk_ram DMEM
    (   .clka(clk), .ena(1'b1), .addra(ADDR_W), .douta(DATA_W),
        .wea(4'b0000), .dina(32'd0)
    );
    
    // Test the tun/tap bus stuff...
    BUS_ShakeTx_tun #( .InWidth(8) )
    BUS_UATX ( ._BUS_(UATX),
        .DataIn(        TX_Data),
        .DataInValid(   TX_Valid),
        .DataInReady(   TX_Ready)
    );
    
    // Test the macro based bus stuff...
    UART uart
    (   .Clock(clk), .Reset(rst),  // Clocks of a feather
        .SIn(FPGA_SERIAL_RX), .SOut(FPGA_SERIAL_TX),
        // Transmitter  (handshakes go both in/out)
        .DataIn(        `ShakeTx_DataIn(        8,UATX)),
        .DataInValid(   `ShakeTx_DataInValid(   8,UATX)),
        .DataInReady(   `ShakeTx_DataInReady(   8,UATX)),
        // Receiver     (handshakes go both in/out)
        .DataOut(       `ShakeRx_DataOut(       8,UARX)),
        .DataOutValid(  `ShakeRx_DataOutValid(  8,UARX)),
        .DataOutReady(  `ShakeRx_DataOutReady(  8,UARX))
    );
    
    
    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
endmodule
