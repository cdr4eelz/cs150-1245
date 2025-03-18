`ifndef CACHE
`define CACHE
// Cache constants
`define IDX_ADDR_OFFSET    3:2      //WAS 4:2
`define IDX_ADDR_INDEX    11:4      //WAS 12:5
`define IDX_ADDR_TAG      27:13
`define IDX_ADDR_DRAM     27:5  //23'b WIDTH

`define IDX_TAG_TAG       18:0
`define IDX_TAG_VALID     19
`define IDX_TAG_DIRTY     20

`define SZ_OFFSET          2    //WAS: 3
`define SZ_INDEX           8
`define SZ_TAG (32-`SZ_OFFSET-`SZ_INDEX-2)
`define SZ_METADATA 2
`define SZ_TAGLINE `SZ_TAG+`SZ_METADATA
`define SZ_CACHELINE 128        //WAS: 256

// `define CAP_CACHE 256 //UNUSED?
// `define SZ_CACHE $clog2(`CAP_CACHE) //UNUSED?

`endif //CACHE
