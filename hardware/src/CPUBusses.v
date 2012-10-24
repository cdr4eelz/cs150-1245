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
