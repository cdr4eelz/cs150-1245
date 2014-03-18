#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

#define BUFFER_LEN (0x00000080) //128-bytes

#define VERSION_I (5)
#define VERSION_C ('0' + VERSION_I)

typedef void (*entry_t)(void);

//TODO:Stash color rather than always as parameter
//TODO:Command-Table with token match-strings => ENUM, then case
//TODO:Arg-List in Command-Table

#define KILLR 0xFFFFFFFF

int main(void)
{
    uwrite_int8s("\r\n\r\n[Golt45.");
    uwrite_int8(VERSION_C);
    uwrite_int8s("]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    color_t sw_color = (color_t)0x4044FFAA;
    color_t gp_color = (color_t)0xC044AAFF;
    gframe_pv sw_frame = STD_FRAME1;
    GP_FRAME = STD_FRAME1;

    for ( ; ; ) {
        uwrite_int8('>'); uwrite_int8(' ');
        int8_t* input = read_token(buffer, BUFFER_LEN, " \x0d");
        bcmd_t bcmd = cmd_token(input);

        switch (bcmd) { //Apply -fjump-tables if you don't have a GOT!!!
            case BC_FILE: {
                store(tok_addr(), tok_dec32u());
            } break;
            case BC_JAL: {
                uint32_t address = (uint32_t)tok_addr();
                entry_t start = (entry_t)address;
                start();
            } break;
            case BC_LW: {
                volatile uint32_t* p = tok_addr();

                bufw_hex32u((uint32_t)p);
                uwrite_int8s(":");
                bufw_hex32u(*p);
                bufw_newline();
            } break;
            case BC_LHU: {
                volatile uint16_t* p = tok_addr();

                bufw_hex32u((uint32_t)p);
                uwrite_int8s(":");
                bufw_hex16u(*p);
                bufw_newline();
            } break;
            case BC_LBU: {
                volatile uint8_t* p = tok_addr();

                bufw_hex32u((uint32_t)p);
                uwrite_int8s(":");
                bufw_hex8u(*p);
                bufw_newline();
            } break;
            case BC_SW: {
                uint32_t word = tok_hex32u();
                volatile uint32_t* p = tok_addr();

                *p = word;
            } break;
            case BC_SH: {
                uint16_t half = tok_hex16u();
                volatile uint16_t* p = tok_addr();

                *p = half;
            } break;
            case BC_SB: {
                uint8_t byte = tok_hex8u ();
                volatile uint8_t* p = tok_addr();

                *p = byte;
            } break;

        //COLT45 extensions:
            case BC_DUMP: {
                uint32_t* address = tok_addr();

                dump_block(address, 16);
                *STASH_ADDR = (address+16);
            } break;
            case BC_COPY: {
                uint32_t* a_src = tok_addr();
                uint32_t* a_dst = (uint32_t*)tok_hex32u();
                uint32_t l_cpy  = tok_hex32u();

                uint32_t xor = copy_xor(a_src, a_dst, l_cpy);

                bufw_hex32u(xor);
                bufw_newline();
            } break;

        //Graphics commands:
            case BC_GS: {
                gstate_tp state = GP_STATE;

                bufw_hex32u( state.u32 );
                uwrite_int8s(" pf#"); bufw_hex8u( state.f.pf_feedframe );
                uwrite_int8( (state.f.video_ready)  ? 'R' : 'r');
                uwrite_int8( (state.f.video_valid)  ? 'V' : 'v');
                uwrite_int8s(" gf#"); bufw_hex8u( state.f.gp_procframe );
                uwrite_int8( (state.f.line_ready)   ? 'L' : 'l');
                uwrite_int8( (state.f.filler_ready) ? 'F' : 'f');
                uwrite_int8( (state.f.gp_ready)     ? 'G' : 'g');
                uwrite_int8s(" sf:"); bufw_hex32u( (uint32_t)sw_frame );
                bufw_newline();
            } break;
            case BC_CC: case BC_SC: case BC_GC: {
                color_t color = (color_t)tok_hex32u();
                if (bcmd != BC_GC) sw_color = color;
                if (bcmd != BC_SC) gp_color = color;
            } break;

            case BC_FF: {
                gframe_pv frame = FRAME_PTR(tok_addr);

                PF_FRAME = frame; //Had trouble doing multiple assign :(
                GP_FRAME = frame;
                sw_frame = frame;
            } break;
            case BC_PF: {
                PF_FRAME = (gframe_pv)tok_hex32u(); //Tests hardware Frame# conversion
            } break;
            case BC_GF: {
                GP_FRAME = FRAME_PTR(tok_hex32u());
            } break;
            case BC_SF: {
                sw_frame = FRAME_PTR(tok_hex32u());
            } break;
            case BC_GP: {
                GP_GCODE = tok_addr();
            } break;

            case BC_FILL: {
                if (gp_color!=KILLR) hwfill(gp_color);
                if (sw_color!=KILLR) swfill(sw_frame, sw_color);
            } break;
            case BC_LINE: {
                uint16_t x0           = tok_dec16u();
                uint16_t y0           = tok_dec16u();
                uint16_t x1           = tok_dec16u();
                uint16_t y1           = tok_dec16u();

                if (gp_color!=KILLR) hwline(gp_color, x0, y0, x1, y1);
                if (sw_color!=KILLR) swline(sw_frame, sw_color, x0, y0, x1, y1);
            } break;
            case BC_PIXL: {
                uint16_t x            = tok_dec16u();
                uint16_t y            = tok_dec16u();

                if (gp_color!=KILLR) hwpixel(gp_color, x, y);
                if (sw_color!=KILLR) swpixel(sw_frame, sw_color, x, y);
            } break;
            case BC_ELIP: {
                uint16_t xc           = tok_dec16u();
                uint16_t yc           = tok_dec16u();
                uint16_t ox           = tok_dec16u();
                uint16_t oy           = tok_dec16u();

                if (gp_color!=KILLR) hwelipse(gp_color, xc, yc, ox, oy);
                if (sw_color!=KILLR) swelipse(sw_frame, sw_color, xc, yc, ox, oy);
            } break;
            case BC_CIRC: {
                uint16_t x            = tok_dec16u();
                uint16_t y            = tok_dec16u();
                uint16_t r            = tok_dec16u();

                if (sw_color!=KILLR) swcircle(sw_frame, sw_color, x, y, r);
            } break;

            BC_UNKNOWN: {
                uwrite_int8('?');
            } //FALLTHROUGH
            default: { //Double "??" for unknown, single "?" for unimplemented/bad-case
                uwrite_int8('?');
                uwrite_int8s(input);
            } break;
        }
    }

    return 0;
}
