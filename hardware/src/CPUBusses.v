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
module BUS_MMAP_tun
( inout `BUS_MMAP_type _BUS_,
    input   [12 -1: 0]  Addr,
    input   [ 4 -1: 0]  WMask,
    input   [32 -1: 0]  WData,
    input   [ 4 -1: 0]  RMask,
    output  [32 -1: 0]  RData
);
    assign `MMAP__IN(_BUS_) = {Addr,WMask,WData,RMask};
    assign {RData} = `MMAP__OUT(_BUS_);
endmodule

module BUS_MMAP_tap
( inout `BUS_MMAP_type _BUS_,
    output  [12 -1: 0]  Addr,
    output  [ 4 -1: 0]  WMask,
    output  [32 -1: 0]  WData,
    output  [ 4 -1: 0]  RMask,
    input   [32 -1: 0]  RData
);
    assign {Addr,WMask,WData,RMask} = `MMAP__IN(_BUS_);
    assign `MMAP__OUT(_BUS_) = {RData};
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
