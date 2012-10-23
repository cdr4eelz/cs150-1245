
module StageWF(
    input  [ 2:0 ] CPUGlobal,
    output [31:0 ] IMEM_read_addr,
    input  [31:0 ] IMEM_read_data,

    input  PCNext,
    
    output [31:0 ] PC,
    output [31:0 ] INST
);

endmodule
