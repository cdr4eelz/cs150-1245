`timescale 100ps / 1ps

`include "CPUBusses.vh"

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
module BUS_MEMIO_tun
( inout `BUS_MEMIO_type _BUS_,
    input   [12 -1: 0]  Addr,
    input   [ 4 -1: 0]  WMask,
    input   [32 -1: 0]  WData,
    input   [ 4 -1: 0]  RMask,
    output  [32 -1: 0]  RData
);
    assign `MEMIO__IN(_BUS_) = {Addr,WMask,WData,RMask};
    assign {RData} = `MEMIO__OUT(_BUS_);
endmodule

module BUS_MEMIO_tap
( inout `BUS_MEMIO_type _BUS_,
    output  [12 -1: 0]  Addr,
    output  [ 4 -1: 0]  WMask,
    output  [32 -1: 0]  WData,
    output  [ 4 -1: 0]  RMask,
    input   [32 -1: 0]  RData
);
    assign {Addr,WMask,WData,RMask} = `MEMIO__IN(_BUS_);
    assign `MEMIO__OUT(_BUS_) = {RData};
endmodule


// TAP/TUN of a DataHandshake Receiver
module BUS_ShakeTx_tun #(parameter InWidth=8)
( inout `BUS_ShakeTx_type(InWidth) _BUS_,
    input                   DataInValid,
    input   [InWidth-1:0]   DataIn,
    output                  DataInReady
);
    assign `ShakeTx_tunIN(InWidth,_BUS_) = {DataInValid,DataIn};
    assign {DataInReady} = `ShakeTx_tunOUT(InWidth,_BUS_);
endmodule

module BUS_ShakeTx_tap #(parameter InWidth=8)
( inout `BUS_ShakeTx_type(InWidth) _BUS_,
    input                   DataInReady,
    output                  DataInValid,
    output  [InWidth-1:0]   DataIn
);
    assign `ShakeTx_tunOUT(InWidth,_BUS_) = {DataInReady};
    assign {DataInValid,DataIn} = `ShakeTx_tunIN(InWidth,_BUS_);
endmodule


// TAP/TUN of a DataHandshake Transmitter
module BUS_ShakeRx_tun #(parameter InWidth=8)
( inout `BUS_ShakeRx_type(InWidth) _BUS_,
    input                   DataOutReady,
    output                  DataOutValid,
    output  [InWidth-1:0]   DataOut
);
    assign `ShakeRx_tunIN(InWidth,_BUS_) = {DataOutReady};
    assign {DataOutValid,DataOut} = `ShakeRx_tunOUT(InWidth,_BUS_);
endmodule

module BUS_ShakeRx_tap #(parameter InWidth=8)
( inout `BUS_ShakeRx_type(InWidth) _BUS_,
    input                   DataOutValid,
    input   [InWidth-1:0]   DataOut,
    output                  DataOutReady
);
    assign `ShakeRx_tunOUT(InWidth,_BUS_) = {DataOutValid,DataOut};
    assign {DataOutReady} = `ShakeRx_tunIN(InWidth,_BUS_);
endmodule
