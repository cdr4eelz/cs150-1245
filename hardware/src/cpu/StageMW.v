`include "../cpuglobal.vh"

/*          Fetch/Read/Write table (blended with old Partition Table)
        ADDR[31:28] TYPE    DEVICE      ACCESS              NOTES
FETCH   4’b0001     PC      I-Cache     Exec/Write
FETCH   4’b0100     PC      BIOS        Exec/Read
FETCH   4’b1100     PC      isr_mem     Exec/Write
FETCH   4’b0110     PC      I-Scratch   Exec/Write  

READ    4’b00x1     Data    D-Cache     Read/Write
READ    4’b0100     Data    BIOS        Read-only
READ    4’b1000     Data    MMIO        Read/Write

WRITE   4’b00x1     Data    D-Cache     Read/Write
WRITE   4’b001x     Code    I-Cache     Exec/Write  Write iif PC[31:28]==4'b0100
WRITE   4’b1000     Data    MMIO        Read/Write
WRITE   4’b1100     Code    isr_mem     Exec/Write

FCH/WR  4’b0110     Code    I-Scratch   Exec/Write  Optional "scratchpad" old IMEM
RD/WR   4’b0101     Data    D-Scratch   Read/Write  Optional "scratchpad" old DMEM
*/

module StageMW (
//NOTE:Currently just asynchronous "control" logic!
//    input clk, rst, stall,

    // Inputs that peek into prior stage (to accommodate synchronous components this stage uses)
    input  wire[ 1: 0]  _MemShift, _MemAddrShift,
    input  wire[31: 0]  _MemWValue,
    input  wire         _MemWrite,

    // Inputs held stable during our stage for us
    input  wire[ 1: 0]  MemShift_MW, MemAddrShift_MW,
    input  wire[31: 0]  RDataRaw,
    input  wire[ 4: 0]  DestReg_MW,
    input  wire         MemToReg_MW,
    input  wire[31: 0]  RegWValue_MW,

    // Outputs fed back to prior stages
    output wire[ 4: 0]  WBK_Reg_,
    output wire[31: 0]  WBK_Val_,
    output wire         WBK_CanFWD_,

    // Memory/IO drives
    output wire[ 3: 0] _WriteMask,
    output wire[31: 0] _WDataMasked
);

    wire [3:0] _ByteMask;
    ByteAccess4 ba4_write (
        .MemShift(_MemShift), .SubIndex(_MemAddrShift), .WordFull(_MemWValue),
        .ByteMask(_ByteMask), .WordMasked(_WDataMasked), .ValExtract()
    );
    assign _WriteMask = (_MemWrite) ? _ByteMask : 4'b0000;

// NOTE: ABOVE THIS SPOT pre/setup staging //
// NOTE: BELOW THIS SPOT post/fetched processing //

    wire [31:0] DataLoad;
    ByteAccess4 ba4_read (
        .MemShift(MemShift_MW), .SubIndex(MemAddrShift_MW), .WordFull(RDataRaw),
        .ByteMask( ), .WordMasked(), .ValExtract(DataLoad)
    );

// WBK outputs (including "can forward" signal)
    assign WBK_Reg_     = DestReg_MW; //Is ZERO when no register writeback is happening
    assign WBK_Val_     = `UNKWIFN( //Jump-Link uses RegWValue_MW
                            (MemToReg_MW) ? DataLoad : RegWValue_MW
                            , 32, DestReg_MW != 0);
    assign WBK_CanFWD_  = `UNKWIFN( //Covers CopRead too (forwarding allowed)
                            (MemToReg_MW) ? 1'b0 : 1'b1
                            ,  1, DestReg_MW != 0);

endmodule
