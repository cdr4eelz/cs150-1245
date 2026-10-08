//DEFINITION MACROS (but NOT instantiated)

#define DEFINE_FROM_ASCII_DEC(type) \
type##_t ascii_dec_to_##type(const char* const s) \
{ \
    type##_t t = 0; \
    for (uint32_t i = 0; i < (((sizeof(type##_t)/sizeof(uint8_t))<<1)+1) && s[i] != '\0'; i++) { \
        if (s[i] >= '0' && s[i] <= '9') { \
            t = (t << 3) + (t << 1) + (s[i] - '0'); \
        } \
    } \
    return t; \
}

#define DEFINE_FROM_ASCII_HEX(type) \
type##_t ascii_hex_to_##type(const char* const s) \
{ \
    type##_t t = 0, i = 0; \
    for ( ; i < ((sizeof(type##_t)/sizeof(uint8_t))<<1) && s[i] != '\0'; i++) { \
        if (s[i] >= '0' && s[i] <= '9') { \
            t = (t << 4) + (s[i] - '0'); \
        } \
        if (s[i] >= 'a' && s[i] <= 'f') { \
            t = (t << 4) + (s[i] - 'a' + 10); \
        } \
        if (s[i] >= 'A' && s[i] <= 'F') { \
            t = (t << 4) + (s[i] - 'A' + 10); \
        } \
    } \
    return t; \
}

#define DEFINE_TO_ASCII_HEX(type) \
int8_t* type##_to_ascii_hex(type##_t const x, int8_t* const buffer, \
                            uint32_t const n) \
{ \
    uint32_t i = 0; \
    uint32_t m = ((sizeof(type##_t) / sizeof(uint8_t)) << 1); \
    for ( ; i < m && i + 1 < n; i++) { \
        int8_t t = (x >> ((m - 1 - i) << 2)) & 0xf; \
        if (t >= 0 && t <= 9) { \
            buffer[i] = t + '0'; \
        } \
        if (t >= 0xa && t <= 0xf) { \
            buffer[i] = (t - 0xa) + 'a'; \
        } \
    } \
    buffer[i] = '\0'; \
    return buffer; \
}

//Can optionally save space by not defining this function:

#ifdef ASCII_WANT_DEC
/*
 * Convert uint32_t to decimal string without using the division (/) or
 * modulo (%) operators.
 *
 * Method:
 *   Pre-compute the powers of ten (10^9 … 10^0).
 *   For each power, count how many times it fits into the remaining
 *   value by repeated subtraction.  That count becomes the digit.
 *   Leading zeros are suppressed.
 *
 * Buffer must be at least 11 bytes.
 */
int8_t* uint32_to_ascii_dec(uint32_t const x, int8_t* const buffer,
                            uint32_t const n)
{
    uint32_t value = x;
    if (value == 0) {
        buffer[0] = '0';
        buffer[1] = '\0';
        return buffer;
    }

    /* 10^9 down to 10^0 */
    static const uint32_t powers[10] = {
        1000000000U,
         100000000U,
          10000000U,
           1000000U,
            100000U,
             10000U,
              1000U,
               100U,
                10U,
                 1U
    };

    char *p = buffer;
    int   started = 0;          /* have we written a non-zero digit yet? */

    for (int i = 0; i < 10; ++i) {
        uint32_t power = powers[i];
        char     digit = '0';

        /* repeated subtraction replaces division */
        while (value >= power) {
            value -= power;
            ++digit;
        }

        /* suppress leading zeros, but always emit the units digit */
        if (digit != '0' || started || i == 9) {
            *p++ = digit;
            started = 1;
        }
    }

    *p = '\0';
    return buffer;
}
#endif // ASCII_WANT_DEC
