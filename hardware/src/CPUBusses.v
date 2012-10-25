`include "CPUBusses.vh"

// CPUGlobal values (driven by CPU, used by innerds)
module BUS_CPUGlobal_tun    // "tunnel" out multiple values
( inout `BUS_CPUGlobal_type _BUS_,
    input CLK, RST, STL
);
    assign `CPUGlobal_tunIN(_BUS_) = {CLK,RST,STL};
endmodule

module BUS_CPUGlobal_tap    // "tap" into desired tunneled values
( inout `BUS_CPUGlobal_type _BUS_,
    output CLK, RST, STL
);
    assign {CLK,RST,STL} = `CPUGlobal_tunIN(_BUS_);
endmodule


// IControl values (driven by decoder, used by everybody)
module BUS_IControl_tun    // "tunnel" out multiple values
( inout `BUS_IControl_type _BUS_,
    input          MemToReg,
    input  [ 4:0 ] DestReg,
    input          MemWrite,
    input  [ 1:0 ] DataWidth,
    input          MSigned,
    input          ALUSrcA,
    input          ALUSrcB,
    input          ISigned,
    input  [ 2:0 ] CmpOp,
    input          Jump,
    input          JR,
    input          Link
);
    assign `IControl_tunIN(_BUS_)
        = {MemToReg,DestReg,MemWrite,DataWidth,MSigned,
            ALUSrcA,ALUSrcB,ISigned,CmpOp,Jump,JR,Link};
endmodule

module BUS_IControl_tap    // "tap" into desired tunneled values
( inout `BUS_IControl_type _BUS_,
    output         MemToReg,
    output [ 4:0 ] DestReg,
    output         MemWrite,
    output [ 1:0 ] DataWidth,
    output         MSigned,
    output         ALUSrcA,
    output         ALUSrcB,
    output         ISigned,
    output [ 2:0 ] CmpOp,
    output         Jump,
    output         JR,
    output         Link
);
    assign {MemToReg,DestReg,MemWrite,DataWidth,MSigned,
        ALUSrcA,ALUSrcB,ISigned,CmpOp,Jump,JR,Link}
            = `IControl_tunIN(_BUS_);
endmodule



// TAP/TUN of a DataHandshake Receiver
module BUS_ShakeRx_tun #(parameter InWidth=8)
( inout `BUS_ShakeRx_type(InWidth) _BUS_,
    input                   DataInValid,
    input   [InWidth-1:0]   DataIn,
    output                  DataInReady
);
    assign `ShakeRx_tunIN(InWidth,_BUS_) = {DataInValid,DataIn};
    assign {DataInReady} = `ShakeRx_tunOUT(InWidth,_BUS_);
endmodule

module BUS_ShakeRx_tap #(parameter InWidth=8)
( inout `BUS_ShakeRx_type(InWidth) _BUS_,
    input                   DataInReady,
    output                  DataInValid,
    output  [InWidth-1:0]   DataIn
);
    assign `ShakeRx_tunOUT(InWidth,_BUS_) = {DataInReady};
    assign {DataInValid,DataIn} = `ShakeRx_tunIN(InWidth,_BUS_);
endmodule


// TAP/TUN of a DataHandshake Transmitter
module BUS_ShakeTx_tun #(parameter InWidth=8)
( inout `BUS_ShakeTx_type(InWidth) _BUS_,
    input                   DataOutReady,
    output                  DataOutValid,
    output  [InWidth-1:0]   DataOut
);
    assign `ShakeTx_tunIN(InWidth,_BUS_) = {DataOutReady};
    assign {DataOutValid,DataOut} = `ShakeTx_tunOUT(InWidth,_BUS_);
endmodule

module BUS_ShakeTx_tap #(parameter InWidth=8)
( inout `BUS_ShakeTx_type(InWidth) _BUS_,
    input                   DataOutValid,
    input   [InWidth-1:0]   DataOut,
    output                  DataOutReady
);
    assign `ShakeTx_tunOUT(InWidth,_BUS_) = {DataOutValid,DataOut};
    assign {DataOutReady} = `ShakeTx_tunIN(InWidth,_BUS_);
endmodule
