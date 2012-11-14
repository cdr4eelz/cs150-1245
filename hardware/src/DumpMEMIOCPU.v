`include "CPUBusses.vh"

module DumpMEMIOCPU (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX
);
    wire stl = stall; // Just friendly rename
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_MEMIO_type         IOMAP;
    
    wire [11: 0]    ADDR, ADDR_NEXT, ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W, IOSTATUS;
    wire [ 7: 0]    TX_Data;
    wire [ 1: 0]    STATE;
    reg  [ 1: 0]    NEXT_STATE;
    
    assign ADDR_NEXT = (STATE == 1) ? (ADDR + 1) : ADDR;
    assign ADDR_W = (ADDR / 4);
    assign ADDR_N = (ADDR % 4);
    assign TX_Data = (ADDR[1])  ? ( (ADDR[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                                : ( (ADDR[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);
    
    always@* begin
        NEXT_STATE = 0;
        case (STATE)
            0: if (IOSTATUS[0]) NEXT_STATE = 1;
            1: NEXT_STATE = 0;
        endcase
    end
    
/*
    integer CNT = 0;
    always@(posedge clk) begin
        $display("R=%b, Next=%d, State=%d", rst, NEXT_STATE, STATE);
        $display("Addr=%h, Data=%h, Status=%h", ADDR, TX_Data, IOSTATUS);
        CNT = CNT + 1;
        if (CNT>300) $finish();
    end
*/    
    BUS_MEMIO_tun BUS_IOMAP( ._BUS_(IOMAP),
        .Addr   ( (STATE == 1) ? 12'h002 : 12'h000 ),
        .RMask  ( (STATE == 1) ? 4'b0000 : 4'b0001 ),
        .WMask  ( (STATE == 1) ? 4'b0001 : 4'b0000 ),
        .RData  ( IOSTATUS ),   .WData  ( {24'b0, TX_Data} )
    );
    
    PipelineRegister #( .Width(2) )
    ADVANCE_REG ( .CPUGlobal(CPUGlobal),
        .In(    NEXT_STATE),
        .Out(   STATE)
    );
    
    PipelineRegister #( .Width(12) )
    ADDR_REG ( .CPUGlobal(CPUGlobal),
        .In(    ADDR_NEXT),
        .Out(   ADDR)
    );
    
    // Key components indirectly wired elsewhere

    dmem_blk_ram DMEM
    (   .clka(clk), .ena(1'b1), .addra(ADDR_W), .douta(DATA_W),
        .wea(4'b0000), .dina(32'd0)
    );
    
    MEMIOPlex iomap_uart
    (   .clk(clk), .rst(rst),
        .SERIAL_RX(FPGA_SERIAL_RX), .SERIAL_TX(FPGA_SERIAL_TX),
        .IOMAP(IOMAP)
    );
    
    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
endmodule
