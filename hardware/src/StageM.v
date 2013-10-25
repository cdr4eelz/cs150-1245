`include "CPUBusses.vh"

module StageM #(
	parameter NOUNKLE = 1
) (
//  inout `BUS_CPUGlobal_type   CPUGlobal,  // Unused!
    inout `BUS_MEMIO_type       DMEM, IMEM, BMEM, IOMAP, // Could be merged & plexed elsewhere
    
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

//NOTE: Is interesting that memories can read/write simultaneously (involving same address)...
//      ...perhaps useful for a special instruction like store-compare (for concurrencty).

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
    
    // An odd but interesting method of BUS plexing, rather than driving a real BUS in tri-state.
    `BUS_MEMIO_type LIVE, DEAD;
    BUS_MEMIO_tun BUS_LIVE( ._BUS_(LIVE),   .RData  (),
        .WMask  (_WMask),                   .RMask  (_RMask),
        .Addr   (_Address),                 .WData  (_WDataMasked)
    );
    BUS_MEMIO_tun BUS_DEAD( ._BUS_(DEAD),   .RData  (),
        .WMask  (4'b0000),                  .RMask  (4'b0000),
        .Addr   (`UNK(0,_Address,12)),      .WData  (`UNK(0,_WDataMasked,32))
    );
    wire _hot_DMEM = ( _Target == 4'b0001 || _Target == 4'b0011 );
    wire _hot_IMEM = ( _Target == 4'b0010 || _Target == 4'b0011 ) && _isWrite && PCPLUS8[30]; // Write-Only & Only if BIOS is running
    wire _hot_BMEM = ( _Target == 4'b0100 && !_isWrite); // Read-Only
    wire _hot_IOMAP= ( _Target == 4'b1000 );
    assign `MEMIO__IN(DMEM) = (_hot_DMEM) ? `MEMIO__IN(LIVE) : `MEMIO__IN(DEAD);
    assign `MEMIO__IN(IMEM) = (_hot_IMEM) ? `MEMIO__IN(LIVE) : `MEMIO__IN(DEAD);
    assign `MEMIO__IN(BMEM) = (_hot_BMEM) ? `MEMIO__IN(LIVE) : `MEMIO__IN(DEAD);
    assign `MEMIO__IN(IOMAP)= (_hot_IOMAP)? `MEMIO__IN(LIVE) : `MEMIO__IN(DEAD);
    
    // Important to note the very cautious use of registered vs passthrough values,
    //   control signals, ets. (Example, DataWidth for read comes from IControl but
    //   DataWidth for write came from _IControl).  Though they are usually the same
    //   value, we don't register it here since the pipeline registers have some extra
    //   features that we yield to.
    
    reg [31: 0] DataRead;
    always @(*) case (Target) // "Target" (for read data coming out after clock) NOT "_Target"
        4'b0001, 4'b0011:   DataRead = `MEMIO_RData(DMEM); // Avoiding casex/casez approach
        4'b0100:            DataRead = `MEMIO_RData(BMEM);
        4'b1000:            DataRead = `MEMIO_RData(IOMAP);
        default: DataRead = `UNK(0,32'h0000,32);
    endcase // CAUTIOUS trapping of EVERY case
    wire [31: 0] DataLoad = DataRead << (SubAddr*8) >> (SubShift*8);
    
    // Might divorce WBK from FWD stuff more fully to clarify slightly different paths
    assign WBK_Reg_ = `ICTL_DestReg(IControl); // Expected to be zero when no writeback
    assign WBK_Val_ = `ICTL_MemToReg(IControl) ? DataLoad :
                        `ICTL_Link(IControl) ? (PCPLUS8) : RegWValue;
    assign WBK_CanFWD_ = !`ICTL_MemToReg(IControl) && (WBK_Reg_ != 0);
    
endmodule
