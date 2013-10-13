`include "CPUBusses.vh"

module DumpMEMIOCPU #(
    parameter DBG_DELAY=0
) (
    input   clk, rst, stall,
    input   FPGA_SERIAL_RX,
    output  FPGA_SERIAL_TX,

    // Memory system ports
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
    output         line_trigger
);
    wire stl = stall; // Just friendly rename
    `BUS_CPUGlobal_type     CPUGlobal;
    `BUS_MEMIO_type         IOMAP;
    
    wire [13: 0]    ADDR, ADDR_NEXT;
    wire [11: 0]    ADDR_W;
    wire [ 1: 0]    ADDR_N;
    wire [31: 0]    DATA_W, IOSTATUS;
    wire [ 7: 0]    TX_Data;
    wire [ 1: 0]    STATE;
    wire [ 1: 0]    NEXT_STATE;
    
    assign #DBG_DELAY ADDR_NEXT = (STATE == 1) ? (ADDR + 1) : ADDR;
    assign #DBG_DELAY ADDR_W   = ADDR[13: 2];
    assign #DBG_DELAY ADDR_N   = ADDR[ 1: 0];
    assign #DBG_DELAY TX_Data  = (ADDR_N[1]) 
                ? ( (ADDR_N[0]) ? DATA_W[ 0 +: 8] : DATA_W[ 8 +: 8])
                : ( (ADDR_N[0]) ? DATA_W[16 +: 8] : DATA_W[24 +: 8]);
    
    assign #DBG_DELAY NEXT_STATE = ((STATE===0) && (IOSTATUS===32'd1)) ? 1 : 0;
    
/*
    integer CNT = 0;
    always@(posedge clk) begin
        $display("R=%b, Next=%d, State=%d", rst, NEXT_STATE, STATE);
        $display("Addr=%h, Data=%h, Status=%h", ADDR, TX_Data, IOSTATUS);
        CNT = CNT + 1;
        if (CNT>30) $finish();
    end
*/
    
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
    
    
    // Drive CPUGlobals from CPU module inputs
    BUS_CPUGlobal_tun BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stl)
    );
    
    
    // Key components indirectly wired elsewhere

    dmem_blk_ram bram_dmem
    (   .clka(clk), .ena(1'b1), .addra(ADDR_W), .douta(DATA_W),
        .wea(4'b0000), .dina(32'd0)
    );
    
    imem_blk_ram bram_imem
    (   .clka(clk), .clkb(clk), .ena(1'b0), //enb(1'b1)
        .addra(12'h000), .wea(4'b0000), .dina(32'd0),
        .addrb(ADDR_W), .doutb()
    );
    
    BUS_MEMIO_tun BUS_IOMAP( ._BUS_(IOMAP),
        .Addr   ( (STATE == 1) ? 12'h002 : 12'h000 ),
        .RMask  ( (STATE == 1) ? 4'b0000 : 4'b0001 ),
        .WMask  ( (STATE == 1) ? 4'b0001 : 4'b0000 ),
        .RData  ( IOSTATUS ),   .WData  ( {24'b0, TX_Data} )
    );
    
    MEMIOPlex iomap_uart
    (   .clk(clk), .rst(rst),
        .SERIAL_RX(FPGA_SERIAL_RX), .SERIAL_TX(FPGA_SERIAL_TX),
        .IOMAP(IOMAP)
    );
    
endmodule
