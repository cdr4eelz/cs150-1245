`include "cpuglobal.vh"

//TODO: Turn into truly global control lines (control/datapath separation)

// IControl values (driven by decoder, used by everybody)
module BUS_ICTL_tun         // "tunnel" out multiple values
( output `BUS_ICTL_type _BUS_,
    input          MemToReg,
    input  [ 4:0 ] DestReg,
    input          MemWrite,
    input  [ 1:0 ] MemShift,
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
        = {MemToReg,DestReg,MemWrite,MemShift,MSigned,
            ALUSrcA,ALUSrcB,ALUOp,ISigned,CmpOp,Jump,JR,Link};
endmodule

module BUS_ICTL_tap         // "tap" into desired tunneled values
( input `BUS_ICTL_type _BUS_,
    output         MemToReg,
    output [ 4:0 ] DestReg,
    output         MemWrite,
    output [ 1:0 ] MemShift,
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
    assign {MemToReg,DestReg,MemWrite,MemShift,MSigned,
        ALUSrcA,ALUSrcB,ALUOp,ISigned,CmpOp,Jump,JR,Link}
            = `ICTL__IN(_BUS_);
endmodule


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
