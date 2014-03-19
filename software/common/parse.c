#include "parse.h"

#include "string.h"
#include "ascii.h"
#include "uart.h"

#define LOCALBUF_LEN 32

bcmdspec_t const bcmd_table[] = {
    {"file",        BC_FILE,      0}, // "?"
    {"jal",         BC_JAL,       0}, // "a"
    {"l" "w",       BC_LW,        0}, // "a"
    {"l" "hu",       BC_LHU,       0}, // "a"
    {"l" "bu",       BC_LBU,       0}, // "a"
    {"s" "w",       BC_SW,        0}, // "wa"
    {"s" "h",        BC_SH,        0}, // "ha"
    {"s" "b",        BC_SB,        0}, // "ba"

    {"dump",        BC_DUMP,      0}, // "aw"
    {"copy",        BC_COPY,      0}, // "aaw"

    {"gstat",       BC_GSTAT,     0}, // ""
    {"gcode",       BC_GCODE,    0}, // "w"
    {"fr",          BC_FRAME,     7}, // "w"
    {"pf" "fr",       BC_FRAME,     4}, // "w"
    {"hw" "fr",       BC_FRAME,     2}, // "w"
    {"sw" "fr",       BC_FRAME,     1}, // "w"

    {"color",       BC_COLOR,     3}, // "w"
    {"hw" "color",    BC_COLOR,     2}, // "w"
    {"sw" "color",    BC_COLOR,     1}, // "w"
    {"fill",        BC_FILL,      0}, // ""
    {"hw" "fill",     BC_FILL,      2}, // ""
    {"sw" "fill",     BC_FILL,      1}, // ""
    {"line",        BC_LINE,      0}, // "hhhh"
    {"hw" "line",     BC_LINE,      2}, // "hhhh"
    {"sw" "line",     BC_LINE,      1}, // "hhhh"
    {"pixl",        BC_PIXL,      0}, // "hh"
    {"hw" "pixl",     BC_PIXL,      2}, // "hh"
    {"sw" "pixl",     BC_PIXL,      1}, // "hh"
    {"elip",        BC_ELIP,      0}, // "hhhh"
    {"hw" "elip",     BC_ELIP,      2}, // "hhhh"
    {"sw" "elip",     BC_ELIP,      1}, // "hhhh"
    {"circ",        BC_CIRC,      0}, // "hhh"

    {"?",           BC_HELP,      0},
    {"?",           BC_UNKNOWN,   0xFFFF},
    {"-",           BC_BLANK,     0xFFFF}
};

const int8_t const DEF_DELIMS[] = " \x0d",
                    *ERRS_ALIGN = "*ALIGN*";

bcmdspec_t* token_cmdspec(const int8_t* const input)
{
    //TODO:Filter odd chars (whitespace)???
    bcmdspec_t *bcs;

    for (bcs = bcmd_table ; (bcs->flags != 0xFFFF) ; bcs++) {
        if (strcmp150(input, bcs->token) == 0) break;
    }
    return bcs;
}

void bufw_cmdspec( void )
{
    bcmdspec_t *bcs;

    bufw_newline();
    for (bcs = bcmd_table ; (bcs->flags != 0xFFFF) ; bcs++) {
        uwrite_int8s(bcs->token); uwrite_int8(' ');
    }
    bufw_newline();
}

int8_t* read_n(int8_t* const bufptr, uint32_t const numBytesBeforeNull)
{
    int8_t *p = bufptr;
    uint32_t n = numBytesBeforeNull;

    if (!n) return NULL; //Nothing to do!!!
    while (n--) {
        *p++ = uread_int8();
    }
    *p = '\0';
    return bufptr;
}

int8_t* read_token(int8_t* const bufptr, uint32_t const buflen,
                   const int8_t* const delimstr) //NULL to use DEF_DELIMS
{
    int8_t *p = bufptr;
    uint32_t n = buflen;
    const int8_t* const delims = (delimstr) ? delimstr : DEF_DELIMS;

    if (!n) return NULL; //No room for null terminator
    while (--n) {
        int8_t dch, ch = uread_int8();
        const int8_t *dp = delims;
        while ((dch=*dp++) != '\0') {
            if (ch == dch) break;
        }
        if (dch != '\0') break; //user entered terminating ch
        *p++ = ch;
    }
    //Buffer filled OR user entered terminating ch
    *p = '\0';
    return bufptr;
}

void store(uint32_t* const pDST, uint32_t const numBytes)
{
    int8_t buffer[9];
    volatile uint32_t *p = (void *)(((uint32_t)pDST) & 0xFFFFFFFC);
    uint32_t words = (numBytes >> 2);

    if ((p != pDST) || (numBytes != (words << 2))) {
        uwrite_int8s(ERRS_ALIGN); //MUST word align!
//      return;
    }
    while (words--) {
        *p++ = ascii_hex_to_uint32(read_n(buffer, 8));
    }
}

const uint32_t* dump_block(const uint32_t* const pSRC, uint8_t const numWords)
{
    const uint32_t *p = (void *)(((uint32_t)pSRC) & 0xFFFFFFFC);

    if (p != pSRC) {
        uwrite_int8s(ERRS_ALIGN); //MUST word align!
    } else {
        for (uint32_t i = 0; i < numWords; i++) {
            if ((i%4)==0) {
                bufw_newline();
                bufw_hex32u((uint32_t) p);
                uwrite_int8(':');
            } else {
                uwrite_int8(' ');
            }
            bufw_hex32u(*p++);
        }
    }
    bufw_newline();
    return p;
}

uint32_t copy_xor(const uint32_t* const pSRC, uint32_t const numBytes,
                  uint32_t* const pDST) //NULL to xor without copy
{
    volatile const uint32_t *s = (void *)(((uint32_t)pSRC) & 0xFFFFFFFC);
    volatile uint32_t *d = (void *)(((uint32_t)pDST) & 0xFFFFFFFC);
    uint32_t words = (numBytes >> 2);
    uint32_t result = 0;

    if ((s != pSRC) || (d != pDST) || (numBytes != (words << 2))) {
        uwrite_int8s(ERRS_ALIGN); //MUST word align!
    } else {
        while (words--) {
            uint32_t val = *s++;
            result ^= val;
            if (pDST) *d++ = val;
        }
    }
    return result;
}

void* tok_addr( void **stash_addr )
{
    void* addr = (void *)tok_hex32u();
    if (stash_addr) {
        if (addr == ((void*)0xFFFFFFFF)) {
            addr = *stash_addr;
        } else {
            *stash_addr = addr;
        }
    }
    return addr;
}

void bufw_newline( void )
{
    uwrite_int8('\r'); uwrite_int8('\n');
}

uint32_t tok_radnum(radixize_t const rz)
{
    int8_t localbuf[LOCALBUF_LEN];
    uint32_t val; //Smaller ints get promoted then demoted (MIPS passes words anyways)
    BOOL negative;

    int8_t *input = read_token(localbuf, LOCALBUF_LEN, NULL);

    if (*input == '-') { //Negative entry (even though unsigned)
        input++; //Advance pointer past the minus sign character
        if (*input == '\0') return 0xFFFFFFFF; //Shortcut for "all bits on"
        negative = TRUE;
    } else negative = FALSE;

    switch (rz) { //NOTE:Compiler tends to need a GOT when doing optimized switch!
        case RZ_HEX32:
            val = ascii_hex_to_uint32(localbuf);
            break;
        case RZ_HEX16:
            val = ascii_hex_to_uint16(localbuf);
            break;
        case RZ_HEX8:
            val = ascii_hex_to_uint8(localbuf);
            break;
        case RZ_DEC32:
            val = ascii_dec_to_uint32(localbuf);
            break;
        case RZ_DEC16:
            val = ascii_dec_to_uint16(localbuf);
            break;
        case RZ_DEC8:
            val = ascii_dec_to_uint8(localbuf);
            break;
        default:
            val = 0x0BADBEEF;
            break;
    }
    return (negative) ? (~val + 1) : val;
}

void bufw_radnum(radixize_t const rz, uint32_t const u32)
{
    int8_t localbuf[LOCALBUF_LEN];

    switch (rz) {
        case RZ_HEX32:
            uint32_to_ascii_hex(u32, localbuf, LOCALBUF_LEN);
            break;
        case RZ_HEX16:
            uint16_to_ascii_hex(u32, localbuf, LOCALBUF_LEN);
            break;
        case RZ_HEX8:
            uint8_to_ascii_hex( u32, localbuf, LOCALBUF_LEN);
            break;
        default:
            localbuf[0] = '?';
            localbuf[1] = '\0';
            break;
    }
    uwrite_int8s(localbuf);
}
