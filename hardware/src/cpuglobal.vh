`ifndef CPUGLOBAL_VH
`define CPUGLOBAL_VH

`define COLT45_DD 0

//NOTE:Trick for tagging signals with foul state in simulation which propagates when misued
`define NOUNKLE         1
`define UNCLEBIT        1'b0
// synthesis translate_off
//`undef UNCLEBIT
//`undef NOUNKLE
//`define UNCLEBIT        1'bz
//`define NOUNKLE         0
// synthesis translate_on

//TODO: Use super-wide constant bus trick rather than requiring width???
`define UNKNOWN(WxW)            ( {WxW{ (`UNCLEBIT) }} )
`define UNKWIFN(VxV,WxW,BxB)    ( ((BxB)||`NOUNKLE) ? (VxV) : `UNKNOWN(WxW) )


//tuninput  {DataValid.1, Data.DIw}
//tunoutput {DataReady.1}
`define BUS_SHAKE_width(DIw)    (1+(DIw)+1)
`define BUS_SHAKE_type( DIw)    wire [(1+(DIw)+1 -1):0]
`define SHAKE_tunIN(    DIw,BUS)BUS [(1+(DIw)+1 -1):1]
`define SHAKE_tunOUT(   DIw,BUS)BUS [(1 -1):0]

`endif //CPUGLOBAL_VH
