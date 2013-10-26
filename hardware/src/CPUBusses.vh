`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

//TODO: Eliminate the BUS tap-macros & require TAP/ADAPT???


//tuninput.3  {CLK.1,RST.1,STL.1}
//tunoutput.0 {}
`define BUS_CPUGlobal_width ((1+1+1)+(0))
`define BUS_CPUGlobal_type  wire [0:`BUS_CPUGlobal_width-1]
`define CPUGlobal__IN(  BUS)BUS [  0 +:  3 ]
`define CPUGlobal__OUT( BUS)BUS [  4 +:  0 ]
`define CPUGlobal_CLK(      BUS)    BUS [  0 +:  1 ]
`define CPUGlobal_RST(      BUS)    BUS [  1 +:  1 ]
`define CPUGlobal_STL(      BUS)    BUS [  2 +:  1 ]


//tuninput.23{MemToReg.1,DestReg.5,MemWrite.1,DataWidth.2,MSigned.1,
//            ALUSrcA.1,ALUSrcB.1,ALUOp.4,ISigned.1,CmpOp.3,Jump.1,JR.1,Link.1}
//tunoutput.0{}
`define BUS_ICTL_width      ((1+5+1+2+1+1+1+4+1+3+1+1+1)+(0)) // 23
`define BUS_ICTL_type       wire [0:`BUS_ICTL_width-1]
`define ICTL__IN(       BUS)BUS [  0 +: 23 ]
`define ICTL__OUT(      BUS)BUS [ 24 +:  0 ]
`define ICTL_MemToReg(      BUS)    BUS [  0 +:  1 ]
`define ICTL_DestReg(       BUS)    BUS [  1 +:  5 ]
`define ICTL_MemWrite(      BUS)    BUS [  6 +:  1 ]
`define ICTL_DataWidth(     BUS)    BUS [  7 +:  2 ]
`define ICTL_MSigned(       BUS)    BUS [  9 +:  1 ]
`define ICTL_ALUSrcA(       BUS)    BUS [ 10 +:  1 ]
`define ICTL_ALUSrcB(       BUS)    BUS [ 11 +:  1 ]
`define ICTL_ALUOp(         BUS)    BUS [ 12 +:  4 ]
`define ICTL_ISigned(       BUS)    BUS [ 16 +:  1 ]
`define ICTL_CmpOp(         BUS)    BUS [ 17 +:  3 ]
`define ICTL_Jump(          BUS)    BUS [ 20 +:  1 ]
`define ICTL_JR(            BUS)    BUS [ 21 +:  1 ]
`define ICTL_Link(          BUS)    BUS [ 22 +:  1 ]


//tuninput.52 {Addr.12,WMask.4,WData.32,RMask.4}
//tunoutput.32{RData.32}
`define BUS_MMAP_width      ((12+4+32+4)+(32)) // 84
`define BUS_MMAP_type       wire [0:`BUS_MMAP_width-1]
`define MMAP__IN(       BUS)BUS [  0 +: 52 ]
`define MMAP__OUT(      BUS)BUS [ 52 +: 32 ]
`define MMAP_Addr(          BUS)    BUS [  0 +: 12 ]
`define MMAP_WMask(         BUS)    BUS [ 12 +:  4 ]
`define MMAP_WData(         BUS)    BUS [ 16 +: 32 ]
`define MMAP_RMask(         BUS)    BUS [ 48 +:  4 ]
`define MMAP_RData(         BUS)    BUS [ 52 +: 32 ]


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
