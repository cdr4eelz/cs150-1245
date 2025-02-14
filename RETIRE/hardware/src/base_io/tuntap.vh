`ifndef TUNTAP_VH
`define TUNTAP_VH

//tuninput  {DataValid.1, Data.DIw}
//tunoutput {DataReady.1}
`define BUS_RVA_width(DIw)    (1+(DIw)+1)
`define BUS_RVA_type( DIw)    wire [(1+(DIw)+1 -1):0]
`define RVA_tunIN(    DIw,BUS)BUS [(1+(DIw)+1 -1):1]
`define RVA_tunOUT(   DIw,BUS)BUS [(1 -1):0]

`endif //TUNTAP_VH
