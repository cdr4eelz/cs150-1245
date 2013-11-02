`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

// Useful for tagging signals (especially bus borne signals) with a foul state in simulation
`define NOUNKLE         1
`define UNCLEBIT        1'b0
// synthesis translate_off
`undef UNCLEBIT
`undef NOUNKLE
`define UNCLEBIT        1'bz
`define NOUNKLE         0
// synthesis translate_on
`define UNKNOWN(WxW)  {WxW{ (`UNCLEBIT) }}


//tuninput.3  {CLK.1,RST.1,STL.1}
//tunoutput.0 {}
`define BUS_CPUGlobal_width ((1+1+1)+(0))
`define BUS_CPUGlobal_type  wire [0:`BUS_CPUGlobal_width-1]
`define CPUGlobal__IN(  BUS)BUS [  0 +:  3 ]
`define CPUGlobal__OUT( BUS)BUS [  4 +:  0 ]


//tuninput.23{MemToReg.1,DestReg.5,MemWrite.1,DataWidth.2,MSigned.1,
//            ALUSrcA.1,ALUSrcB.1,ALUOp.4,ISigned.1,CmpOp.3,Jump.1,JR.1,Link.1}
//tunoutput.0{}
`define BUS_ICTL_width      ((1+5+1+2+1+1+1+4+1+3+1+1+1)+(0)) // 23
`define BUS_ICTL_type       wire [0:`BUS_ICTL_width-1]
`define ICTL__IN(       BUS)BUS [  0 +: 23 ]
`define ICTL__OUT(      BUS)BUS [ 24 +:  0 ]


//tuninput  {DataValid.1, Data.DIw}
//tunoutput {DataReady.1}
`define BUS_SHAKE_width(DIw)    (1+(DIw)+1)
`define BUS_SHAKE_type( DIw)    wire [1+(DIw)+1 -1:0]
`define SHAKE_tunIN(    DIw,BUS)BUS [1+(DIw)+1 -1:1]
`define SHAKE_tunOUT(   DIw,BUS)BUS [1 -1:0]

`define SHAKE_DataValid(    DIw,BUS)    BUS[1+(DIw)+1 -1: (DIw)+1]
`define SHAKE_Data(         DIw,BUS)    BUS[  (DIw)+1 -1:       1]
`define SHAKE_DataReady(    DIw,BUS)    BUS[        1 -1:       0]

`endif //CPUBUSSES_VH
