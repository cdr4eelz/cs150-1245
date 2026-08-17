`timescale 1ns/1ps

`include "cpuglobal.vh"
`include "tuntap.vh"

// TAP/TUN of Ready/Valid handshake BUS
module BUS_RVA_tun #(parameter InWidth=8)
( inout `BUS_RVA_type(InWidth) _BUS_,
    input                   DataValid,
    input  [(InWidth-1):0]  Data,
    output                  DataReady
);
    assign `RVA_tunIN(InWidth,_BUS_) = {DataValid,Data};
    assign {DataReady} = `RVA_tunOUT(InWidth,_BUS_);
endmodule

module BUS_RVA_tap #(parameter InWidth=8)
( inout `BUS_RVA_type(InWidth) _BUS_,
    input                   DataReady,
    output                  DataValid,
    output [(InWidth-1):0]  Data
);
    assign `RVA_tunOUT(InWidth,_BUS_) = {DataReady};
    assign {DataValid,Data} = `RVA_tunIN(InWidth,_BUS_);
endmodule
