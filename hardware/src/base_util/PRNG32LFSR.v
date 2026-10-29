// From a web search for random linear feedback shift register (LFSR) implementations
// This module implements a 32-bit Galois LFSR-based pseudo-random number generator (PRNG)
// The output sequence will repeat after 2^32 - 1 cycles if seeded with a NON-ZERO value

module PRNG32LFSR (
    input  wire        clk,
    input  wire        rst_n,    // Active-low asynchronous reset
    input  wire        load_seed,// Pulse to load a new starting state
    input  wire [31:0] seed_val, // Seed MUST be non-zero
    output reg  [31:0] prng_out
);

    // Feedback mask matching polynomial: X^32 + X^22 + X^2 + X^1 + 1
    localparam [31:0] POLY_MASK = 32'h80200003; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prng_out <= 32'hACE1_2468; // Default non-zero seed
        end else if (load_seed) begin
            // Avoid all-zero lockup state
            prng_out <= (seed_val == 32'h0) ? 32'h1 : seed_val;
        end else begin
            // Galois LFSR shift operation
            if (prng_out[0]) begin
                prng_out <= (prng_out >> 1) ^ POLY_MASK;
            end else begin
                prng_out <= (prng_out >> 1);
            end
        end
    end

endmodule
