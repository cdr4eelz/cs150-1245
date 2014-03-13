#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

//BUFFER_LEN moved to parse.h and new BUFFER_FIX for fixed buffer pointer

#define VERSION_I (1)
#define VERSION_C '1'
#define VERSION_S "1"

typedef void (*entry_t)(void);

int main(void)
{
    uwrite_int8s("\r\n\r\n[Golt45." VERSION_S "]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    uint32_t* stash_addr1 = (uint32_t*)0x10000000;
    gframe_p sw_frame = (gframe_p)0x00000001;

    for ( ; ; ) {
        uwrite_int8(VERSION_C);
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
            bufw_newline();
        } else if (strcmp150(input, "lhu") == 0) {
            uint32_t address      = tok_hex32u();

            volatile uint16_t* p  = (volatile uint16_t*)(address);

            bufw_hex32u(address);
            uwrite_int8s(":");
            bufw_hex16u(*p);
            bufw_newline();
        } else if (strcmp150(input, "lbu") == 0) {
            uint32_t address      = tok_hex32u();

            volatile uint8_t* p = (volatile uint8_t*)(address);

            bufw_hex32u(address);
            uwrite_int8s(":");
            bufw_hex8u(*p);
            bufw_newline();
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
            gstate_t state = GP_STATE;
            bufw_hex32u( state.u32 );
            bufw_newline();

        } else if (strcmp150(input, "pf") == 0) {
            gframe_p frame = (gframe_p)tok_hex32u();
            PF_FRAME = frame;

        } else if (strcmp150(input, "sf") == 0) {
            gframe_p frame = (gframe_p)tok_hex32u();
            sw_frame = frame;
            GP_FRAME = frame;

        } else if (strcmp150(input, "gf") == 0) {
            gframe_p frame = (gframe_p)tok_hex32u();
            GP_FRAME = frame;

        } else if (strcmp150(input, "gc") == 0) {
            gpcode_p code = (gpcode_p)tok_hex32u();
            GP_GCODE = code;

        } else if (strcmp150(input, "hwfill") == 0) {
            color_t color = (color_t)tok_hex32u();
            hwfill(color);

        } else if (strcmp150(input, "hwline") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();
            hwline(color, x0, y0, x1, y1);

        } else if (strcmp150(input, "hwpixel") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            hwpixel(color, x, y);

        } else if (strcmp150(input, "hwelipse") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t xc           = tok_dec16u();
            uint16_t yc           = tok_dec16u();
            uint16_t ox           = tok_dec16u();
            uint16_t oy           = tok_dec16u();
            hwelipse(color, xc, yc, ox, oy);

        } else if (strcmp150(input, "swfill") == 0) {
            uint32_t color        = tok_hex32u();
            swfill(sw_frame, color);

        } else if (strcmp150(input, "swline") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();
            swline(sw_frame, color, x0, y0, x1, y1);

        } else if (strcmp150(input, "swpixel") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            swpixel(sw_frame, color, x, y);

        } else if (strcmp150(input, "swelipse") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t xc           = tok_dec16u();
            uint16_t yc           = tok_dec16u();
            uint16_t ox           = tok_dec16u();
            uint16_t oy           = tok_dec16u();
            swelipse(sw_frame, color, xc, yc, ox, oy);

        } else if (strcmp150(input, "swcircle") == 0) {
            uint32_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            uint16_t r            = tok_dec16u();
            swcircle(sw_frame, color, x, y, r);

//COLT45 "custom" extensions:
        } else if (strcmp150(input, "dump") == 0) {
            uint32_t* address = (uint32_t*)tok_hex32u();
            if (!address) {
                address = stash_addr1;
                stash_addr1 += 16;
            } else {
                stash_addr1 = address;
            }

            show_block(address, 16);
            bufw_newline();
        } else if (strcmp150(input, "cp") == 0) {
            uint32_t* a_src = (uint32_t*)tok_hex32u();
            uint32_t* a_dst = (uint32_t*)tok_hex32u();
            uint32_t l_cpy  = tok_hex32u();

            uint32_t xor = copy_xor(a_src, a_dst, l_cpy);

            bufw_hex32u(xor);
            bufw_newline();
        }
    }

    return 0;
}
