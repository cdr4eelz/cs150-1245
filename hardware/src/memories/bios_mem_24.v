`timescale 1ns/1ns

module bios_mem_24 (
    input clk,
    input ena,
    input [11:0] addra,
    output reg [31:0] douta,
    input enb,
    input [11:0] addrb,
    output reg [31:0] doutb
);
    reg [31:0] mem [4096-1:0];
    always @(posedge clk) begin
        if (ena) begin
            douta <= mem[addra];
        end
    end

    always @(posedge clk) begin
        if (enb) begin
            doutb <= mem[addrb];
        end
    end

//  `define STRINGIFY_BIOS2(x) `"x/../software/bios151v3/bios151v3.hex`"
//  `define STRINGIFY_BIOS2(x) `"x/../software/bios150v3/bios150v3.inst.hex`"
    `define STRINGIFY_BIOS2(x) `"x/../software/echo_i/echo_i.inst.hex`"
//  `define STRINGIFY_BIOS2(x) `"x/../software/testdata/testdata.hex`"
//  `define STRINGIFY_BIOS2(x) `"x/../software/gios/gios.inst.coe`"

    `ifdef SYNTHESIS
        initial begin
            $readmemh(`STRINGIFY_BIOS2(`ABS_TOP), mem);
        end
    `endif
endmodule
