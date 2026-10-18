// Helper top-level module for the Icarus Verilog flow in Makefile (SIM=icarus).
// Compiled next to the testbench with -s icarus_ctl -DICARUS_TOP=<Testbench>.
//   +vcd=<file>    dump all signals under the testbench to <file>
//   +stop_ns=<n>   end the simulation after <n> ns (0 = no limit)
`timescale 1ns/1ps
module icarus_ctl;
    reg [8*512-1:0] vcd_file;
    reg [63:0] stop_ns;
    initial begin
        if ($value$plusargs("vcd=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, `ICARUS_TOP);
        end
        if ($value$plusargs("stop_ns=%d", stop_ns) && stop_ns != 0) begin
            #(stop_ns);
            $display("icarus_ctl: stop time of %0d ns reached, ending simulation", stop_ns);
            $finish;
        end
    end
endmodule
