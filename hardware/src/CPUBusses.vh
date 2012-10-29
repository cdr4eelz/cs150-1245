`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

//tuninput.3  {CLK.1,RST.1,STL.1}
//tunoutput.0 {}
`define BUS_CPUGlobal_width     ((1+1+1)+(0))
`define BUS_CPUGlobal_type      tri [     0: 3 - 1]
`define CPUGlobal_tunIN(BUS)    BUS [     0: 3 - 1]
`define CPUGlobal_tunOUT(BUS)   BUS [ 0 - 1: 0 - 1]
`define CPUGlobal_CLK(BUS)      BUS [  0 +:  1]
`define CPUGlobal_RST(BUS)      BUS [  1 +:  1]
`define CPUGlobal_STL(BUS)      BUS [  2 +:  1]

//tuninput  {MemToReg.1,DestReg.5,MemWrite.1,DataWidth.2,MSigned.1,
//            ALUSrcA.1,ALLUSrcB.1,ALUop.4,ISigned.1,CmpOp.3,Jump.1,JR.1,Link.1}
//tunoutput {}
`define BUS_IControl_width    (1+5+1+2+1+1+1+1+3+1+1+1) // 19
`define BUS_IControl_type     tri  [19 -1: 0]
`define IControl_tunIN(BUS)   BUS[19 -1: 0]
//`define IControl_tunOUT(BUS)  


//tuninput  {DataInValid.1, DataIn.DIw}
//tunoutput {DataInReady.1}
`define BUS_ShakeTx_width(DIw)      (1+(DIw)+1)
`define BUS_ShakeTx_type(DIw)       tri  [1+(DIw)+1 -1:0]
`define ShakeTx_tunIN(DIw,BUS)      BUS[1+(DIw)+1 -1:1]
`define ShakeTx_tunOUT(DIw,BUS)     BUS[1 -1:0]
`define ShakeTx_DataInValid(DIw,BUS)    BUS[1+(DIw)+1 -1: (DIw)+1]
`define ShakeTx_DataIn(DIw,BUS)         BUS[  (DIw)+1 -1:       1]
`define ShakeTx_DataInReady(DIw,BUS)    BUS[        1 -1:       0]

//tuninput  {DataOutReady.1}
//tunoutput {DataOutValid.1, DataOut.mDW}
`define BUS_ShakeRx_width(DOw)      (1+1+(DOw))
`define BUS_ShakeRx_type(DOw)       tri  [1+1+(DOw) -1:        0]
`define ShakeRx_tunIN(DOw,BUS)      BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeRx_tunOUT(DOw,BUS)     BUS[  1+(DOw) -1:        0]
`define ShakeRx_DataOutReady(DOw,BUS)   BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeRx_DataOutValid(DOw,BUS)   BUS[  1+(DOw) -1:    (DOw)]
`define ShakeRx_DataOut(DOw,BUS)        BUS[    (DOw) -1:        0]

`endif //CPUBUSSES_VH
