`ifndef CPUBUSSES_VH
`define CPUBUSSES_VH

task UnpackCRS;
    input  [ 2:0 ] CRS;
    output clk, rst, stl;
    begin
        {clk, rst, stl} = CRS;
    end
endtask

`endif // CPUBUSSES_VH
