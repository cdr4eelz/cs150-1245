`ifndef BRANCHCMPOP
`define BRANCHCMPOP

// These will get merged eventually for simplicity!!!

`define FULLCMP_False  3'b000
`define FULLCMP_LT     3'b001
`define FULLCMP_GE     3'b010
`define FULLCMP_True   3'b011
`define FULLCMP_EQ     3'b100
`define FULLCMP_NE     3'b101
`define FULLCMP_LE     3'b110
`define FULLCMP_GT     3'b111


`define BRANCHCMP_False  `FULLCMP_False
`define BRANCHCMP_LTz    `FULLCMP_LT
`define BRANCHCMP_GEz    `FULLCMP_GE
`define BRANCHCMP_True   `FULLCMP_True
`define BRANCHCMP_EQab   `FULLCMP_EQ
`define BRANCHCMP_NEab   `FULLCMP_NE
`define BRANCHCMP_LEz    `FULLCMP_LE
`define BRANCHCMP_GTz    `FULLCMP_GT

`endif //BRANCHCMPOP
