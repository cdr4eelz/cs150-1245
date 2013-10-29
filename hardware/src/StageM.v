`include "CPUBusses.vh"

module StageM #(
	parameter NOUNKLE=0,
    parameter COLT45_MEMWRITE=1
)(
    input `BUS_CPUGlobal_type CPUGlobal,
    // Inputs that peek into prior stage (to accommodate synchronous components this stage uses)
    input `BUS_ICTL_type _IControl, // Few are used (hopefully tools will prune)
    input  [31: 0]  _MemWValue,
    input  [31: 0]  _MemAddr,
    // Inputs held stable during our stage for us
    input `BUS_ICTL_type IControl,  // Not all are used (hopefully tools will prune)
    input  [31: 0]  MemAddr,
    input  [31: 0]  RegWValue,
    input  [31: 0]  PCPLUS8,
    // Outputs fed back to prior stages
    output [ 4: 0]  WBK_Reg_,
    output [31: 0]  WBK_Val_,
    output          WBK_CanFWD_,
    // Passthroughs (not sync'd with StageM)
    input  [31: 0]  INST_ADDR, // StageWF INST fetch
    output [31: 0]  INST_DATA,
    inout `BUS_SHAKE_type(8) UATX, UARX
);
`define UNKNOWN 'bz
`define UNK(CONDITION,DEFAULT,WIDTH) (((CONDITION) || NOUNKLE) ? (DEFAULT) : (WIDTH`UNKNOWN))

    wire clk, rst, stall;
    BUS_CPUGlobal_tap BUS_CPUGlobal
    ( ._BUS_(CPUGlobal),
        .CLK(clk), .RST(rst), .STL(stall)
    );

    //TODO: Double-tap the control lines & avoid breaking down MemAddr's
    wire  [ 3: 0] _Target   = _MemAddr[31:28],
                   Target   =  MemAddr[31:28];
    wire  [ 1: 0] _SubAddr  = _MemAddr[ 1: 0],
                   SubAddr  =  MemAddr[ 1: 0];
    wire  [ 1: 0] _SubShift = (3 - `ICTL_DataWidth(_IControl)),
                   SubShift = (3 - `ICTL_DataWidth( IControl));
    wire  [ 3: 0]  DestReg  = `ICTL_DestReg( IControl);
    wire    _isWrite    = `ICTL_MemWrite(_IControl),
             isWrite    = `ICTL_MemWrite( IControl);
    wire    _isRead     = `ICTL_MemToReg(_IControl),
             isRead     = `ICTL_MemToReg( IControl);
    wire     isLink     = `ICTL_Link(IControl);
    // read/write/link should be exclusive of eachother

    wire  [31: 0] _WDataMasked  = (_MemWValue) << (_SubShift*8) >> (_SubAddr*8);
    wire  [ 3: 0] _ByteMask     = (   4'b1111) << (_SubShift  ) >> (_SubAddr  );
    wire  [ 3: 0] _WriteMask    = _ByteMask & {4{_isWrite}};

// NOTE: Cautious selection of _IControl vs IControl based signals.

//TODO: Convert to PARAMETER that disables/adjusts MEMRANGE as appropriate (or a little submodule or compact BUS-of-enable)
//TODO: Convert to always@*
    wire _hot_IO = ( _Target == 4'b1000 );
`ifdef COLT45_pre2
    wire _hot_BR = 1'b0;
    wire _hot_DC = 1'b0;
    wire _hot_IC = 1'b0;
    wire _hot_DB = ( _Target == 4'b0001 || _Target == 4'b0011 );
    wire _hot_IB = ( _Target == 4'b0010 || _Target == 4'b0011 ) && _isWrite; // W-0 (Write-Only)
`else
    wire _hot_BR = ( _Target == 4'b0100 && !_isWrite); // Read-Only as Data (can be "enforced" elsewhere)
    wire _hot_DC = ( _Target == 4'b0001 || _Target == 4'b0011 );
    wire _hot_IC = ( _Target == 4'b0010 || _Target == 4'b0011 ) && _isWrite && PCPLUS8[30]; // Write-Only & Bios-Only
`ifdef COLT45_STRICT
    wire _hot_DB = 1'b0;
    wire _hot_IB = 1'b0;
`else
    wire _hot_DB = ( _Target == 4'b0111 );              //EXTRA: Scratchpad-RAM
    wire _hot_IB = ( _Target == 4'b0110 ) && _isWrite;  //EXTRA: Scratchpad-EXE
`endif
`endif

    wire [31: 0] RData_IO, RData_BR, RData_DC, RData_DB;
    wire INST_bios = (INST_ADDR[31:28] == 4'h4);
    wire [31:0] INST_BR, INST_IB;
    assign INST_DATA = (INST_bios) ? INST_BR : INST_IB; //TODO: ICACHE

    reg [31: 0] DataRead; // Registered elsewhere (is just a reg here because of always@*)
    always @(*) case (Target) // "Target" (for read data coming out after clock) NOT "_Target"
        4'b1000: DataRead = RData_IO;
`ifdef COLT45_pre2
        4'b0001,
        4'b0011: DataRead = RData_DB;
`else
        4'b0100: DataRead = RData_BR;
        4'b0001,
        4'b0011: DataRead = RData_DC;
`ifndef COLT45_STRICT //TODO: Ensure no other references to these if STRICT mode!
        4'b0110: DataRead = RData_DB; // Stash old BRAMs as scratchpad-RAM
`endif
`endif
        default: DataRead = `UNK(0,32'h0000,32);
    endcase // CAUTIOUS trapping of EVERY case


    wire [31: 0] DataLoad = DataRead << (SubAddr*8) >> (SubShift*8);

    // Might divorce WBK from FWD stuff more fully to clarify slightly different paths
    assign WBK_Reg_ = DestReg; // Expected to be zero when no writeback
    assign WBK_Val_ = (isRead) ? DataLoad : ( (isLink) ? (PCPLUS8) : RegWValue );
    assign WBK_CanFWD_ = !isRead && (DestReg != 0);


    // MEMORY & IO ELEMENTS THEMSELVES

    MEMIOPlex iomap_uart
    ( .clk(clk), .rst(rst), .ena(~stall && _hot_IO),
        .addra(_MemAddr[13:2]),
        .douta(RData_IO),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked),
        .RVA_RX(UARX), .RVA_TX(UATX)
    );

    bios_mem brom_bios
    ( .clka(clk), .ena(~stall && _hot_BR),
        .addra(_MemAddr[13:2]),
        .douta(RData_BR),//OUT-32
      /*.wea(_WriteMask), .dina(_WDataMasked),*/

    // Instruction reading port (b)
      .clkb(clk), .addrb(INST_ADDR[13:2]),
        .enb(INST_bios), .doutb(INST_BR)
    ) /* synthesis syn_noprune=1 */;

// Do these fetch half-words & bytes?
assign RData_DC = 32'bz; //dcache_dout
// INST_IC=instruction
// icache_addr=(INST_ADDR/DATA_ADDR/NONE)

    dmem_blk_ram bram_dmem
    ( .clka(clk), .ena(~stall && _hot_DB),
        .addra(_MemAddr[13:2]),
        .douta(RData_DB),//OUT-32
        .wea(_WriteMask), .dina(_WDataMasked)
    ) /* synthesis syn_noprune=1 */;

    imem_blk_ram bram_imem
    ( .clka(clk), .ena(~stall && _hot_IB),
        .addra(_MemAddr[13:2]),
      /*.douta(RData_IB),//OUT-32*/
        .wea(_WriteMask), .dina(_WDataMasked),

    // INSTRUCTION Fletch
      .clkb(clk), .addrb(INST_ADDR[13:2]),
      /*.enb(1'b1)*/ .doutb(INST_IB)
    ) /* synthesis syn_noprune=1 */;


// synthesis translate_off
generate if (COLT45_MEMWRITE) begin:_MEMWRITE_
    always@(posedge clk) if (~stall && _isWrite) begin
        // Plan to log these into a sequential list of critical actions (for stricter testing)
        $display("** [%h,%d] <= %h(%d) {%b}",
            _MemAddr, _MemAddr, _WDataMasked, _WDataMasked, _WriteMask);
        $display("** IO=%b BR=%b IC=%b DB=%b IB=%b",
            _hot_IO, _hot_BR, _hot_IC, _hot_DB, _hot_IB);
    end
end endgenerate
// synthesis translate_on

endmodule
