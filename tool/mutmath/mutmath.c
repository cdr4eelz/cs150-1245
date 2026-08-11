#include "mutmath.h"

/*
uint32_t mul32u(uint16_t n, uint16_t m)
__attribute__ ((weak, alias ("mut_mul32u_branchless") ));

uint32_t sqr32u(uint16_t n)
__attribute__ ((weak, alias ("mut_sqr32u_branchless") ));
*/



uint32_t mut_mul32u_naive(uint16_t n, uint16_t m)
{
//  return n*m;
    uint32_t prod = 0;

    if (n < m) {
        while (n--) prod += m;
    } else {
        while (m--) prod += n;
    }
    return prod;
}

/* Russian Peasant / Binary Long Multiplication algorithm */
uint32_t mut_mul32u_quick(uint16_t a, uint16_t b) {
    uint32_t result = 0;
    while (b > 0) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    return result;
}

/**
 * @brief Product of two unsigned 16-bit integers as 32-bit .
 * @note Completely branchless and unrolled to maximize execution speed on MIPS I.
 * @param m1 First unsigned 16-bit operand.
 * @param m2 Second unsigned 16-bit operand.
 * @return The unsigned 32-bit result (m1 * m2).
 */
uint32_t mut_mul32u_branchless(uint16_t m1, uint16_t m2) {
    uint32_t r = 0;
    uint32_t a = m1;
    uint32_t b = m2;

    // Unrolled Unsigned 16-bit Multiplication Engine
    // We check bits of 'b' and conditionally add 'a' using bitwise masks.
    r += a & -(uint32_t)(b & 1);        a <<= 1;
    r += a & -(uint32_t)((b >> 1) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 2) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 3) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 4) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 5) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 6) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 7) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 8) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 9) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 10) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 11) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 12) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 13) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 14) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 15) & 1);

    return r;
}

/**
 * @brief Computes the absolute value of a 16-bit signed integer branchlessly.
 * @note Optimized for architectures like MIPS I.
 */
   static inline uint32_t mut_abs16s_ext32(int16_t x) {
    uint32_t mask = x >> 15; // 0x00000000 if positive, 0xFFFFFFFF if negative
    return (x + mask) ^ mask; // Branchless
}

/**
 * @brief Multiplies two signed 16-bit integers without a hardware multiplier.
 * @note Completely branchless and unrolled to maximize execution speed on MIPS I.
 * @param m1 First signed 16-bit operand.
 * @param m2 Second signed 16-bit operand.
 * @return The signed 32-bit result (m1 * m2).
 */
int32_t mut_mul32s_branchless(int16_t m1, int16_t m2) {
    // 1. Determine the sign of the final result using XOR
    // If signs differ, sign_mask becomes 0xFFFFFFFF. If they match, 0x00000000.
    int32_t sign_mask = (m1 ^ m2) >> 15;

    // 2. Convert both operands to absolute (unsigned) values branchlessly
    uint32_t a = mut_abs16s_ext32(m1);
    uint32_t b = mut_abs16s_ext32(m2);

    // 3. Unrolled Unsigned 16-bit Multiplication Engine
    // We check bits of 'b' and conditionally add 'a' using bitwise masks.
    uint32_t r = 0;

    r += a & -(uint32_t) (b       & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 1) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 2) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 3) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 4) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 5) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 6) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 7) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 8) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 9) & 1);  a <<= 1;
    r += a & -(uint32_t)((b >> 10) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 11) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 12) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 13) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 14) & 1); a <<= 1;
    r += a & -(uint32_t)((b >> 15) & 1);

    // 4. Restore the sign branchlessly
    // If sign_mask is 0xFFFFFFFF, this computes: (r ^ 0xFFFFFFFF) + 1, which is -r.
    // If sign_mask is 0x00000000, it computes: (r ^ 0) + 0, which keeps r positive.
    return (uint32_t)((r ^ sign_mask) - sign_mask);
}


// SQUARE (n * n) functions:

uint32_t mut_sqr32u_naive(uint16_t n)
{
    return mut_mul32s_branchless(n,n); // Use whicever multiplication function is active
}

/**
 * @brief Square of 16-bit unsigned integer as 32-bit unsigned.
 * @note Optimized for MIPS I. Completely branchless and unrolled.
 *       Guarantees execution in a fixed, ultra-low number of clock cycles.
 * @param x The 16-bit unsigned integer to square (0 to 65535).
 * @return The 32-bit unsigned squared result (x^2).
 */
uint32_t mut_sqr32u_branchless(uint16_t x) {
    uint32_t r = 0;
    uint32_t a = x;

    // Bit 0
    r += a & -(uint32_t)(a & 1);
    a <<= 1;
    // Bit 1
    r += a & -(uint32_t)((a >> 1) & 1);
    a <<= 1;
    // Bit 2
    r += a & -(uint32_t)((a >> 2) & 1);
    a <<= 1;
    // Bit 3
    r += a & -(uint32_t)((a >> 3) & 1);
    a <<= 1;
    // Bit 4
    r += a & -(uint32_t)((a >> 4) & 1);
    a <<= 1;
    // Bit 5
    r += a & -(uint32_t)((a >> 5) & 1);
    a <<= 1;
    // Bit 6
    r += a & -(uint32_t)((a >> 6) & 1);
    a <<= 1;
    // Bit 7
    r += a & -(uint32_t)((a >> 7) & 1);
    a <<= 1;
    // Bit 8
    r += a & -(uint32_t)((a >> 8) & 1);
    a <<= 1;
    // Bit 9
    r += a & -(uint32_t)((a >> 9) & 1);
    a <<= 1;
    // Bit 10
    r += a & -(uint32_t)((a >> 10) & 1);
    a <<= 1;
    // Bit 11
    r += a & -(uint32_t)((a >> 11) & 1);
    a <<= 1;
    // Bit 12
    r += a & -(uint32_t)((a >> 12) & 1);
    a <<= 1;
    // Bit 13
    r += a & -(uint32_t)((a >> 13) & 1);
    a <<= 1;
    // Bit 14
    r += a & -(uint32_t)((a >> 14) & 1);
    a <<= 1;
    // Bit 15
    r += a & -(uint32_t)((a >> 15) & 1);

    return r;
}
