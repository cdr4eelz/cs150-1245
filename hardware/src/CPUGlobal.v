`include "cpuglobal.vh"

// TAP/TUN of a DataHandshake Ready/Valid bus
module BUS_SHAKE_tun #(parameter InWidth=8)
( inout `BUS_SHAKE_type(InWidth) _BUS_,
    input                   DataValid,
    input  [(InWidth-1):0]  Data,
    output                  DataReady
);
    assign `SHAKE_tunIN(InWidth,_BUS_) = {DataValid,Data};
    assign {DataReady} = `SHAKE_tunOUT(InWidth,_BUS_);
endmodule

module BUS_SHAKE_tap #(parameter InWidth=8)
( inout `BUS_SHAKE_type(InWidth) _BUS_,
    input                   DataReady,
    output                  DataValid,
    output [(InWidth-1):0]  Data
);
    assign `SHAKE_tunOUT(InWidth,_BUS_) = {DataReady};
    assign {DataValid,Data} = `SHAKE_tunIN(InWidth,_BUS_);
endmodule
