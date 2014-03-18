#include "parse.h"

#include "string.h"
#include "ascii.h"
#include "uart.h"

bcmd_t cmd_token(const int8_t* const input)
{
    bcmd_t bcmd;

    if (strcmp150(input, "file") == 0) return BC_FILE;
    if (strcmp150(input, "jal" ) == 0) return BC_JAL;
    if (strcmp150(input, "lw"  ) == 0) return BC_LW;
    if (strcmp150(input, "lhu" ) == 0) return BC_LHU;
    if (strcmp150(input, "lbu" ) == 0) return BC_LBU;
    if (strcmp150(input, "sw"  ) == 0) return BC_SW;
    if (strcmp150(input, "sh"  ) == 0) return BC_SH;
    if (strcmp150(input, "sb"  ) == 0) return BC_SB;

    if (strcmp150(input, "dump") == 0) return BC_DUMP;
    if (strcmp150(input, "copy") == 0) return BC_COPY;

    if (strcmp150(input, "gs") == 0) return BC_GS;
    if (strcmp150(input, "sc") == 0) return BC_SC;
    if (strcmp150(input, "gc") == 0) return BC_GC;
    if (strcmp150(input, "cc") == 0) return BC_CC;

    if (strcmp150(input, "ff") == 0) return BC_FF;
    if (strcmp150(input, "pf") == 0) return BC_PF;
    if (strcmp150(input, "gf") == 0) return BC_GF;
    if (strcmp150(input, "sf") == 0) return BC_SF;
    if (strcmp150(input, "gp") == 0) return BC_GP;

    if (strcmp150(input, "fill") == 0) return BC_FILL;
    if (strcmp150(input, "line") == 0) return BC_LINE;
    if (strcmp150(input, "pixl") == 0) return BC_PIXL;
    if (strcmp150(input, "elip") == 0) return BC_ELIP;
    if (strcmp150(input, "circ") == 0) return BC_CIRC;
    return BC_UNKNOWN;
}

int8_t* read_n(int8_t* const bufptr, uint32_t const buflen)
{
    int8_t *p = bufptr;
    uint32_t n = buflen;
    if (!p || !n) return NULL; //Protect caller from themselves!
    while (n--) {
        *p++ = uread_int8();
    }
    *p = '\0';
    return bufptr;
}

int8_t* read_token(int8_t* const bufptr, uint32_t const buflen, const int8_t* const ds)
{
    int8_t *p = bufptr;
    uint32_t n = buflen;
    if (!p || !n) return NULL; //Protect caller from themselves!
    while (n--) {
        int8_t dch, ch = uread_int8();
        const int8_t *dp = ds;
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

void store(volatile uint32_t* const address, uint32_t const numBytes)
{
    int8_t buffer[9];
    volatile uint32_t* p = address;

    if (((uint32_t)address) & 0x00000003) return; //Insist on word alignment
    uint32_t words = (numBytes >> 2);
    while (words-- > 0) {
        *p++ = ascii_hex_to_uint32(read_n(buffer,8));
    }
}

void dump_block(uint32_t* const address, uint8_t const numWords)
{
    uint32_t* p = address;
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
    bufw_newline();
}

uint32_t copy_xor(uint32_t* const pSRC, uint32_t* const pDST, uint32_t const numBytes)
{
    uint32_t result = 0;
    uint32_t* s = pSRC;
    uint32_t* d = pDST;
    uint32_t words = (numBytes >> 2);
    while (words--) {
        uint32_t val = *s++;
        result ^= val;
        if (pDST) *d++ = val;
    }
    return result;
}

#define LOCALBUF_LEN 32

void* tok_addr( void ) {
    void *addr = (void *)tok_hex32u();
    if (!addr) {
        addr = *STASH_ADDR;
    } else {
        *STASH_ADDR = addr;
    }
    return addr;
}

void bufw_newline( void ) {
    uwrite_int8('\r'); uwrite_int8('\n');
}

uint16_t tok_dec16u() {
    int8_t localbuf[LOCALBUF_LEN];

    int8_t* input = read_token(localbuf, LOCALBUF_LEN, " \x0d");
    uint16_t val = ascii_dec_to_uint16(input);
    return val;
}

uint32_t tok_radnum(radixize_t const rz) {
    int8_t localbuf[LOCALBUF_LEN];

    read_token(localbuf, LOCALBUF_LEN, " \x0d");
    uint32_t val; //Smaller uints get promoted (MIPS passes words anyways)
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
    uwrite_int8s(localbuf);
    return val;
}

void bufw_radnum(radixize_t const rz, uint32_t const u32) {
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
