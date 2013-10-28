`include "CPUBusses.vh"

module StageM #(
	parameter NOUNKLE=1
)(
//  inout `BUS_CPUGlobal_type   CPUGlobal,  // Unused!
    inout `BUS_MMAP_type        IO2MMAP, BIOSROM, DACACHE, ITCACHE, DATBRAM, INSBRAM, //TODO: Merge & plex elsewhere off single BUS

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
    output          WBK_CanFWD_
);
`define UNKNOWN 'b0
`define UNK(CONDITION,DEFAULT,WIDTH) (((CONDITION) || NOUNKLE) ? (DEFAULT) : (WIDTH`UNKNOWN))


    // These are looking more like Functions due to the symmetry & triviality
    wire  [ 3: 0] _Target   = _MemAddr[31:28],
                   Target   =  MemAddr[31:28];
    wire  [11: 0] _Address  = _MemAddr[13: 2],
                   Address  =  MemAddr[13: 2];
    wire  [ 1: 0] _SubAddr  = _MemAddr[ 1: 0],
                   SubAddr  =  MemAddr[ 1: 0];
    wire  [ 1: 0] _SubShift = (3 - `ICTL_DataWidth(_IControl)),
                   SubShift = (3 - `ICTL_DataWidth( IControl));
    wire    _isWrite    = `ICTL_MemWrite(_IControl),
             isWrite    = `ICTL_MemWrite( IControl);
    wire    _isRead     = `ICTL_MemToReg(_IControl),
             isRead     = `ICTL_MemToReg( IControl);

    // This little compute block could become a nifty primitive!
    wire  [31: 0] _WDataMasked  = (_MemWValue) << (_SubShift*8) >> (_SubAddr*8);
    wire  [ 3: 0] _ByteMask     = (   4'b1111) << (_SubShift  ) >> (_SubAddr  );
    wire  [ 3: 0] _WMask    = (_isWrite) ? _ByteMask : 4'b0000;
    wire  [ 3: 0] _RMask    = (_isRead ) ? _ByteMask : 4'b0000;

// NOTE: Cautious selection of _IControl vs IControl based signals.

//TODO: Convert to PARAMETER that disables/adjusts MEMRANGE as appropriate (or a little submodule or compact BUS-of-enable)
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
`ifndef COLT45_STRICT
    wire _hot_DB = ( _Target == 4'b0111 );              //EXTRA: Scratchpad-RAM
    wire _hot_IB = ( _Target == 4'b0110 ) && _isWrite;  //EXTRA: Scratchpad-EXE
`endif
`endif


//TODO: RETIRE cluttered multi-bus approach for simpler scheme.
    wire [31:0] RData_IO, RData_BR, RData_DC, RData_DB; //Read data lines
    BUS_MMAP_tun BUS_IO( ._BUS_(IO2MMAP), ._STALL_(~_hot_IO),
        .RData  (RData_IO),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );
    BUS_MMAP_tun BUS_BR( ._BUS_(BIOSROM), ._STALL_(~_hot_BR),
        .RData  (RData_BR),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );
    BUS_MMAP_tun BUS_DC( ._BUS_(DACACHE), ._STALL_(~_hot_DC),
        .RData  (RData_DC),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );
    BUS_MMAP_tun BUS_IC( ._BUS_(ITCACHE), ._STALL_(~_hot_IC),
        .RData  (/*RData_IC*/),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );
    BUS_MMAP_tun BUS_DB( ._BUS_(DATBRAM), ._STALL_(~_hot_DB),
        .RData  (RData_DB),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );
    BUS_MMAP_tun BUS_IB( ._BUS_(INSBRAM), ._STALL_(~_hot_IB),
        .RData  (/*RData_IB*/),
        .Addr   (_Address),                 .WData  (_WDataMasked),
        .RMask  (_RMask),                   .WMask  (_WMask)
    );


    reg [31: 0] DataRead;
    always @(*) case (Target) // "Target" (for read data coming out after clock) NOT "_Target"
        4'b1000:            DataRead = RData_IO;
`ifdef COLT45_pre2
        4'b0001, 4'b0011:   DataRead = RData_DB;
`else
        4'b0100:            DataRead = RData_BR;
        4'b0001, 4'b0011:   DataRead = RData_DC;
`ifndef COLT45_STRICT //TODO: Ensure no other references to these if STRICT mode!
        4'b0110:            DataRead = RData_DB; // Stash old BRAMs as scratchpad-RAM
`endif
`endif
        default: DataRead = `UNK(0,32'h0000,32);
    endcase // CAUTIOUS trapping of EVERY case
    wire [31: 0] DataLoad = DataRead << (SubAddr*8) >> (SubShift*8);


    // Might divorce WBK from FWD stuff more fully to clarify slightly different paths
    assign WBK_Reg_ = `ICTL_DestReg( IControl); // Expected to be zero when no writeback
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? DataLoad :
                          `ICTL_Link(IControl) ? (PCPLUS8) : RegWValue;
    assign WBK_CanFWD_ = !`ICTL_MemToReg(IControl) && (WBK_Reg_ != 0);

endmodule
