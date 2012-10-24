`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

//tuninput  {CLK 1,RST 1,STL 1}
//tunoutput {}
`define BUS_CPUGlobal_width     (1+1+1)
`define BUS_CPUGlobal_type      tri  [1+1+1 -1: 0]
`define CPUGlobal_tunIN(BUS)    BUS[1+1+1 -1: 0]
`define CPUGlobal_tunOUT(BUS)   BUS[           ]
`define CPUGlobal_CLK(BUS)          BUS[1+1+1 -1:  1+1]
`define CPUGlobal_RST(BUS)          BUS[  1+1 -1:    1]
`define CPUGlobal_STL(BUS)          BUS[    1 -1:    0]

//tuninput  {DataInValid 1, DataIn DIw}
//tunoutput {DataInReady 1}
`define BUS_ShakeRx_width(DIw)      (1+(DIw)+1)
`define BUS_ShakeRx_type(DIw)       tri  [1+(DIw)+1 -1:0]
`define ShakeRx_tunIN(DIw,BUS)      BUS[1+(DIw)+1 -1:1]
`define ShakeRx_tunOUT(DIw,BUS)     BUS[1 -1:0]
`define ShakeRx_DataInValid(DIw,BUS)    BUS[1+(DIw)+1 -1: (DIw)+1]
`define ShakeRx_DataIn(DIw,BUS)         BUS[  (DIw)+1 -1:       1]
`define ShakeRx_DataInReady(DIw,BUS)    BUS[        1 -1:       0]

//tuninput  {DataOutReady 1}
//tunoutput {DataOutValid 1, DataOut mDW}
`define BUS_ShakeTx_width(DOw)      (1+1+(DOw))
`define BUS_ShakeTx_type(DOw)       tri  [1+1+(DOw) -1:        0]
`define ShakeTx_tunIN(DOw,BUS)      BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeTx_tunOUT(DOw,BUS)     BUS[  1+(DOw) -1:        0]
`define ShakeTx_DataOutReady(DOw,BUS)   BUS[1+1+(DOw) -1:  1+(DOw)]
`define ShakeTx_DataOutValid(DOw,BUS)   BUS[  1+(DOw) -1:    (DOw)]
`define ShakeTx_DataOut(DOw,BUS)        BUS[    (DOw) -1:        0]

`endif //CPUBUSSES_VH
