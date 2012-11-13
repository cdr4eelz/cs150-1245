`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

//tuninput.3  {CLK.1,RST.1,STL.1}
//tunoutput.0 {}
`define BUS_CPUGlobal_width ((1+1+1)+(0))
`define BUS_CPUGlobal_type  wire [0:`BUS_CPUGlobal_width-1]
`define CPUGlobal__IN(BUS)  BUS [  0 +:  3 ]
`define CPUGlobal__OUT(BUS) BUS [  4 +:  0 ]
`define CPUGlobal_CLK(      BUS)    BUS [  0 +:  1 ]
`define CPUGlobal_RST(      BUS)    BUS [  1 +:  1 ]
`define CPUGlobal_STL(      BUS)    BUS [  2 +:  1 ]

//tuninput.23{MemToReg.1,DestReg.5,MemWrite.1,DataWidth.2,MSigned.1,
//            ALUsrcA.1,ALUsrcB.1,ALUop.4,ISigned.1,CmpOp.3,Jump.1,JR.1,Link.1}
//tunoutput.0{}
`define BUS_ICTL_width  ((1+5+1+2+1+1+1+4+1+3+1+1+1)+(0)) // 23
`define BUS_ICTL_type   wire [0:`BUS_ICTL_width-1]
`define ICTL__IN(BUS)   BUS [  0 +: 23 ]
`define ICTL__OUT(BUS)  BUS [ 24 +:  0 ]
`define ICTL_MemToReg(  BUS)    BUS [  0 +:  1 ]
`define ICTL_DestReg(   BUS)    BUS [  1 +:  5 ]
`define ICTL_MemWrite(  BUS)    BUS [  6 +:  1 ]
`define ICTL_DataWidth( BUS)    BUS [  7 +:  2 ]
`define ICTL_MSigned(   BUS)    BUS [  9 +:  1 ]
`define ICTL_ALUSrcA(   BUS)    BUS [ 10 +:  1 ]
`define ICTL_ALLUSrcB(  BUS)    BUS [ 11 +:  1 ]
`define ICTL_ALUop(     BUS)    BUS [ 12 +:  4 ]
`define ICTL_ISigned(   BUS)    BUS [ 16 +:  1 ]
`define ICTL_CmpOp(     BUS)    BUS [ 17 +:  3 ]
`define ICTL_Jump(      BUS)    BUS [ 20 +:  1 ]
`define ICTL_JR(        BUS)    BUS [ 21 +:  1 ]
`define ICTL_Link(      BUS)    BUS [ 22 +:  1 ]


//tuninput.52 {Addr.12,WMask.4,WData.32,RMask.4}
//tunoutput.32{RData.32}
`define BUS_MEMIO_width     ((12+4+32+4)+(32)) // 84
`define BUS_MEMIO_type      wire [0:`BUS_MEMIO_width-1]
`define MEMIO__IN(BUS)      BUS [  0 +: 52 ]
`define MEMIO__OUT(BUS)     BUS [ 52 +: 32 ]
`define MEMIO_Addr(         BUS)    BUS [  0 +: 12 ]
`define MEMIO_WMask(        BUS)    BUS [ 12 +:  4 ]
`define MEMIO_WData(        BUS)    BUS [ 16 +: 32 ]
`define MEMIO_RMask(        BUS)    BUS [ 48 +:  4 ]
`define MEMIO_RData(        BUS)    BUS [ 52 +: 32 ]


//tuninput  {DataInValid.1, DataIn.DIw}
//tunoutput {DataInReady.1}
`define BUS_ShakeTx_width(DIw)      (1+(DIw)+1)
`define BUS_ShakeTx_type(DIw)       wire [1+(DIw)+1 -1:0]
`define ShakeTx_tunIN(DIw,BUS)      BUS[1+(DIw)+1 -1:1]
`define ShakeTx_tunOUT(DIw,BUS)     BUS[1 -1:0]
`define ShakeTx_DataInValid(DIw,BUS)    BUS[1+(DIw)+1 -1: (DIw)+1]
`define ShakeTx_DataIn(DIw,BUS)         BUS[  (DIw)+1 -1:       1]
`define ShakeTx_DataInReady(DIw,BUS)    BUS[        1 -1:       0]

//tuninput  {DataOutReady.1}
//tunoutput {DataOutValid.1, DataOut.mDW}
`define BUS_ShakeRx_width(DOw)      (1+1+(DOw))
`define BUS_ShakeRx_type(DOw)       wire [1+1+(DOw) -1:        0]
`define ShakeRx_tunIN(DOw,BUS)      BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeRx_tunOUT(DOw,BUS)     BUS[  1+(DOw) -1:        0]
`define ShakeRx_DataOutReady(DOw,BUS)   BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeRx_DataOutValid(DOw,BUS)   BUS[  1+(DOw) -1:    (DOw)]
`define ShakeRx_DataOut(DOw,BUS)        BUS[    (DOw) -1:        0]

`endif //CPUBUSSES_VH
