
module BUS_CPUGlobal_module
(
    inout  [ 2:0 ] BUS,
    inout  wire CLK,
    inout  wire RST,
    inout  wire STL
);

assign BUS = {CLK,RST,STL};

endmodule
