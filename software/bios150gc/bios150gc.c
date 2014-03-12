#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

//BUFFER_LEN moved to parse.h and new BUFFER_FIX for fixed buffer pointer

#define VERSION_CHAR '5'

typedef void (*entry_t)(void);

int main(void)
{
    uwrite_int8s("\r\n\r\n[COLT45.");
    uwrite_int8(VERSION_CHAR);
    uwrite_int8s("]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    uint32_t stash_addr1 = 0x10000000;
    uint32_t sw_frame = 0x00000001;

    for ( ; ; ) {
        uwrite_int8(VERSION_CHAR);
        uwrite_int8('>');
        uwrite_int8(' ');

        int8_t* input = tok_word();

        if (strcmp150(input, "file") == 0) {
            uint32_t address      = tok_hex32u();
            uint32_t file_length  = tok_dec32u();

            store(address, file_length);
        } else if (strcmp150(input, "jal") == 0) {
            uint32_t address      = tok_hex32u();

            entry_t start = (entry_t)(address);
            start();
        } else if (strcmp150(input, "lw") == 0) {
            uint32_t address      = tok_hex32u();

            volatile uint32_t* p  = (volatile uint32_t*)(address);

            bufw_hex32u(address);
            uwrite_int8s(":");
            bufw_hex32u(*p);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "lhu") == 0) {
            uint32_t address      = tok_hex32u();

            volatile uint16_t* p  = (volatile uint16_t*)(address);

            bufw_hex32u(address);
            uwrite_int8s(":");
            bufw_hex16u(*p);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "lbu") == 0) {
            uint32_t address      = tok_hex32u();

            volatile uint8_t* p = (volatile uint8_t*)(address);

            bufw_hex32u(address);
            uwrite_int8s(":");
            bufw_hex8u(*p);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "sw") == 0) {
            uint32_t word         = tok_hex32u();
            uint32_t address      = tok_hex32u();

            volatile uint32_t* p = (volatile uint32_t*)(address);
            *p = word;
        } else if (strcmp150(input, "sh") == 0) {
            uint16_t half         = tok_hex16u();
            uint32_t address      = tok_hex32u();

            volatile uint16_t* p = (volatile uint16_t*)(address);
            *p = half;
        } else if (strcmp150(input, "sb") == 0) {
            uint8_t byte          = tok_hex8u ();
            uint32_t address      = tok_hex32u();

            volatile uint8_t* p = (volatile uint8_t*)(address);
            *p = byte;

//Graphics commands:
        } else if (strcmp150(input, "gs") == 0) {
            uint32_t status = GP_CONTROL;

            bufw_hex32u(status);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "pf") == 0) {
            uint32_t frame        = tok_hex32u();

            PF_FRAME = frame;
        } else if (strcmp150(input, "sf") == 0) {
            uint32_t frame        = tok_hex32u();

            sw_frame = frame;
            GP_FRAME = frame;
        } else if (strcmp150(input, "gf") == 0) {
            uint32_t frame        = tok_hex32u();

            GP_FRAME = frame;
        } else if (strcmp150(input, "gc") == 0) {
            uint32_t code         = tok_hex32u();

            GP_CODE = code;
        } else if (strcmp150(input, "hwfill") == 0) {
            uint32_t color        = tok_hex32u();

            hwfill(color);
        } else if (strcmp150(input, "hwline") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();

            hwline(color, x0, y0, x1, y1);
        } else if (strcmp150(input, "hwpixel") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();

            hwpixel(color, x, y);
        } else if (strcmp150(input, "hwcircle") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            uint16_t r            = tok_dec16u();

            hwcircle(color, x, y, r);
        } else if (strcmp150(input, "swfill") == 0) {
            uint32_t color        = tok_hex32u();

            swfill(color, sw_frame);
        } else if (strcmp150(input, "swline") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();

            swline(color, x0, y0, x1, y1, sw_frame);
        } else if (strcmp150(input, "swpixel") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();

            swpixel(color, x, y, sw_frame);
        } else if (strcmp150(input, "swcircle") == 0) {
            uint32_t color        = tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            uint16_t r            = tok_dec16u();

            swcircle(color, x, y, r, sw_frame);

//COLT45 "custom" extensions:
        } else if (strcmp150(input, "dump") == 0) {
            uint32_t address      = tok_hex32u();
            if (address == 0) {
                address = stash_addr1;
                stash_addr1 += (16 * 4);
            } else {
                stash_addr1 = address;
            }

            show_block(address, 16, buffer, BUFFER_LEN);
            uwrite_int8s("\r\n");
        } else if (strcmp150(input, "cp") == 0) {
            uint32_t a_src        = tok_hex32u();
            uint32_t a_dst        = tok_hex32u();
            uint32_t l_cpy        = tok_hex32u();

            uint32_t xor = copy_xor(a_src, a_dst, l_cpy);

            bufw_hex32u(xor);
            uwrite_int8s("\r\n");
        }
    }

    return 0;
}
