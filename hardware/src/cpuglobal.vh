`ifndef CPUGLOBAL_VH
`define CPUGLOBAL_VH

`define COLT45_DD 0

//NOTE:For tagging signals with foul state in simulation which propagates when misued
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

`default_nettype none

`endif //CPUGLOBAL_VH
