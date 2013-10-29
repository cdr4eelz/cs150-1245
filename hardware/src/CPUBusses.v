`include "CPUBusses.vh"

//TODO: Use PARAMs on MMAP to select mem-range (perhaps other masking like stall)
//TODO: Teach chipscope the BUS ranges (some-day)

// CPUGlobal values (driven by CPU, used by innerds)
module BUS_CPUGlobal_tun    // "tunnel" out multiple values
( output `BUS_CPUGlobal_type _BUS_,
    input CLK, RST, STL
);
    assign `CPUGlobal__IN(_BUS_) = {CLK,RST,STL};
endmodule

module BUS_CPUGlobal_tap    // "tap" into desired tunneled values
( input `BUS_CPUGlobal_type _BUS_,
    output CLK, RST, STL
);
    assign {CLK,RST,STL} = `CPUGlobal__IN(_BUS_);
endmodule


// IControl values (driven by decoder, used by everybody)
module BUS_ICTL_tun         // "tunnel" out multiple values
( output `BUS_ICTL_type _BUS_,
    input          MemToReg,
    input  [ 4:0 ] DestReg,
    input          MemWrite,
    input  [ 1:0 ] DataWidth,
    input          MSigned,
    input          ALUSrcA,
    input          ALUSrcB,
    input  [ 3:0 ] ALUOp,
    input          ISigned,
    input  [ 2:0 ] CmpOp,
    input          Jump,
    input          JR,
    input          Link
);
    assign `ICTL__IN(_BUS_)
        = {MemToReg,DestReg,MemWrite,DataWidth,MSigned,
            ALUSrcA,ALUSrcB,ALUOp,ISigned,CmpOp,Jump,JR,Link};
endmodule

module BUS_ICTL_tap         // "tap" into desired tunneled values
( input `BUS_ICTL_type _BUS_,
    output         MemToReg,
    output [ 4:0 ] DestReg,
    output         MemWrite,
    output [ 1:0 ] DataWidth,
    output         MSigned,
    output         ALUSrcA,
    output         ALUSrcB,
    output [ 3:0 ] ALUOp,
    output         ISigned,
    output [ 2:0 ] CmpOp,
    output         Jump,
    output         JR,
    output         Link
);
    assign {MemToReg,DestReg,MemWrite,DataWidth,MSigned,
        ALUSrcA,ALUSrcB,ALUOp,ISigned,CmpOp,Jump,JR,Link}
            = `ICTL__IN(_BUS_);
endmodule


// TAP/TUN of a Memory/IO access (Memory Stage inputs, CPU/MemController outputs)
module xBUS_MMAP_tun
( inout `xBUS_MMAP_type _BUS_,
    input   [32 -1: 2]  AddrW,
    input   [ 4 -1: 0]  MaskB,
    input   [32 -1: 0]  WData,
    output  [32 -1: 0]  RData
);
    assign `xMMAP__IN(_BUS_) = {AddrW,MaskB,WData};
    assign {RData} = `xMMAP__OUT(_BUS_);
endmodule

module xBUS_MMAP_tap
( inout `xBUS_MMAP_type _BUS_,
    output  [32 -1: 2]  AddrW,
    output  [ 4 -1: 0]  MaskB,
    output  [32 -1: 0]  WData,
    input   [32 -1: 0]  RData
);
    assign {AddrW,MaskB,WData} = `xMMAP__IN(_BUS_);
    assign `xMMAP__OUT(_BUS_) = {RData};
endmodule


// TAP/TUN of a DataHandshake Ready/Valid bus
module BUS_SHAKE_tun #(parameter InWidth=8)
( inout `BUS_SHAKE_type(InWidth) _BUS_,
    input                   DataValid,
    input   [InWidth-1:0]   Data,
    output                  DataReady
);
    assign `SHAKE_tunIN(InWidth,_BUS_) = {DataValid,Data};
    assign {DataReady} = `SHAKE_tunOUT(InWidth,_BUS_);
endmodule

module BUS_SHAKE_tap #(parameter InWidth=8)
( inout `BUS_SHAKE_type(InWidth) _BUS_,
    input                   DataReady,
    output                  DataValid,
    output  [InWidth-1:0]   Data
);
    assign `SHAKE_tunOUT(InWidth,_BUS_) = {DataReady};
    assign {DataValid,Data} = `SHAKE_tunIN(InWidth,_BUS_);
endmodule
