
module DDRStage #(
    parameter LITTLEWORDIAN=0 //Order of 32-bit words in each 256-bit DDR block (not byte order)
)(
    input           clk, rst,

//DDR FIFOs (read-only):
    input           raf_full,
    input           raf_wren, //Ignored if rdf_rden (meaning busy with pending read)
    output reg      rdf_rden,  //"Caller" waits until !rdf_rden before next use
    input           rdf_wren,  //From memory RequestController
    input   [127:0] rdf_data,   //  (likewise)

//DDR chunk (256-bits)
    output reg          chunk_valid,
    output reg [255:0]  chunk_data
);

    reg  halfvalid;

    wire [127:0] data = (LITTLEWORDIAN)
                            ? {rdf_data[31:0], rdf_data[63:32],
                                rdf_data[95:64], rdf_data[127:96]
                            } : rdf_data[127:0];

    always @(posedge clk) begin
        if (rst) begin
            rdf_rden <= 1'b0;
            chunk_valid <= 1'b0;
            halfvalid <= 1'b0;
        end else begin
            if (rdf_rden) begin
                if (rdf_wren) begin
                    if (halfvalid ^ LITTLEWORDIAN) begin
                        chunk_data[127:  0] <= data;
                    end else begin
                        chunk_data[255:128] <= data;
                    end
                    rdf_rden <= !halfvalid;
                    chunk_valid <= halfvalid;
                    halfvalid <= 1'b1;
                end
            end else if (raf_wren) begin
                rdf_rden <= !raf_full;
                chunk_valid <= 1'b0;
                halfvalid <= 1'b0;
                chunk_data <= 256'b0;
            end
        end
    end

endmodule
