#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

//BUFFER_LEN moved to parse.h and new BUFFER_FIX for fixed buffer pointer

#define VERSION_I (2)
#define VERSION_C ('0' + VERSION_I)

typedef void (*entry_t)(void);

//TODO:Stash color rather than always as parameter
//TODO:Command-Table with token match-strings => ENUM, then case
//TODO:Arg-List in Command-Table
//TODO:GS nice output

int main(void)
{
    uwrite_int8s("\r\n\r\n[Golt45.");
    uwrite_int8(VERSION_C);
    uwrite_int8s("]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    gframe_p sw_frame = STD_FRAME1;
    GP_FRAME = sw_frame;

    for ( ; ; ) {
        uwrite_int8('>');
        uwrite_int8(' ');

        int8_t* input = tok_word();

        if (strcmp150(input, "file") == 0) {
            uint32_t address      = tok_hex32u();
            uint32_t file_length  = tok_dec32u();

            store(address, file_length);
        } else if (strcmp150(input, "jal") == 0) {
            entry_t start = (entry_t)tok_addr();

            bufw_hex32u((uint32_t)start);
            bufw_newline();
            start();
        } else if (strcmp150(input, "lw") == 0) {
            volatile uint32_t* p  = (volatile uint32_t*)tok_addr();

            bufw_hex32u((uint32_t)p);
            uwrite_int8s(":");
            bufw_hex32u(*p);
            bufw_newline();
        } else if (strcmp150(input, "lhu") == 0) {
            volatile uint16_t* p  = (volatile uint16_t*)tok_addr();

            bufw_hex32u((uint32_t)p);
            uwrite_int8s(":");
            bufw_hex16u(*p);
            bufw_newline();
        } else if (strcmp150(input, "lbu") == 0) {
            volatile uint8_t* p = (volatile uint8_t*)tok_addr();

            bufw_hex32u((uint32_t)p);
            uwrite_int8s(":");
            bufw_hex8u(*p);
            bufw_newline();
        } else if (strcmp150(input, "sw") == 0) {
            uint32_t word         = tok_hex32u();
            volatile uint32_t* p = (volatile uint32_t*)tok_addr();

            *p = word;
        } else if (strcmp150(input, "sh") == 0) {
            uint16_t half         = tok_hex16u();
            volatile uint16_t* p = (volatile uint16_t*)tok_addr();

            *p = half;
        } else if (strcmp150(input, "sb") == 0) {
            uint8_t byte          = tok_hex8u ();
            volatile uint8_t* p = (volatile uint8_t*)tok_addr();

            *p = byte;

//Graphics commands:
        } else if (strcmp150(input, "gs") == 0) {
            gstate_t state = GP_STATE;
            bufw_hex32u( state.u32 );
            bufw_newline();

        } else if (strcmp150(input, "pf") == 0) {
            PF_FRAME = (gframe_p)tok_hex32u();
        } else if (strcmp150(input, "sf") == 0) {
            sw_frame = (gframe_p)tok_hex32u();
            GP_FRAME = sw_frame;
        } else if (strcmp150(input, "gf") == 0) {
            GP_FRAME = (gframe_p)tok_hex32u();

        } else if (strcmp150(input, "gc") == 0) {
            GP_GCODE = (gpcode_p)tok_addr();

        } else if (strcmp150(input, "hwfill") == 0) {
            color_t color = (color_t)tok_hex32u();
            hwfill(color);

        } else if (strcmp150(input, "hwline") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();
            hwline(color, x0, y0, x1, y1);

        } else if (strcmp150(input, "hwpixel") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            hwpixel(color, x, y);

        } else if (strcmp150(input, "hwelipse") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t xc           = tok_dec16u();
            uint16_t yc           = tok_dec16u();
            uint16_t ox           = tok_dec16u();
            uint16_t oy           = tok_dec16u();
            hwelipse(color, xc, yc, ox, oy);

        } else if (strcmp150(input, "swfill") == 0) {
            color_t color = (color_t)tok_hex32u();
            swfill(sw_frame, color);

        } else if (strcmp150(input, "swline") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t x0           = tok_dec16u();
            uint16_t y0           = tok_dec16u();
            uint16_t x1           = tok_dec16u();
            uint16_t y1           = tok_dec16u();
            swline(sw_frame, color, x0, y0, x1, y1);

        } else if (strcmp150(input, "swpixel") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            swpixel(sw_frame, color, x, y);

        } else if (strcmp150(input, "swelipse") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t xc           = tok_dec16u();
            uint16_t yc           = tok_dec16u();
            uint16_t ox           = tok_dec16u();
            uint16_t oy           = tok_dec16u();
            swelipse(sw_frame, color, xc, yc, ox, oy);

        } else if (strcmp150(input, "swcircle") == 0) {
            color_t color = (color_t)tok_hex32u();
            uint16_t x            = tok_dec16u();
            uint16_t y            = tok_dec16u();
            uint16_t r            = tok_dec16u();
            swcircle(sw_frame, color, x, y, r);

//COLT45 "custom" extensions:
        } else if (strcmp150(input, "dump") == 0) {
            uint32_t* address = (uint32_t*)tok_addr();

            show_block(address, 16);
            *STASH_ADDR = (address + 16);
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
