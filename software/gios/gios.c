#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

#define BUFFER_LEN (0x00000080) //128-bytes

#define VERSION_I (6)
#define VERSION_C ('0' + VERSION_I)
#define VERSION_S STIFIE(VERSION_I)
#define STIFIE(Z) STIFIY(Z) //Stringify expanded macro value of Z
#define STIFIY(Z) #Z //Stringify argument Z

#define KILLR 0xFFFFFFFF

typedef void (*entry_t)(void);


int main(void)
{
    uwrite_int8s("\r\n\r\n[Golt45." VERSION_S "]\r\n\r\n");

    int8_t buffer[BUFFER_LEN];
    void* stash_address = (void*)0x10000000;
    bcmdspec_t* priorbcs = NULL;

    color_t sw_argb = (color_t)0x4044FFAA;
    color_t gp_argb = (color_t)0xC044AAFF;
    gframe_pv sw_frame = STD_FRAME1;
    GP_FRAME = STD_FRAME1;

    for ( ; ; ) {
        uwrite_int8('>'); uwrite_int8(' ');
        int8_t* input = read_token(buffer, BUFFER_LEN, NULL);
        bcmdspec_t* bcs = token_cmdspec(input);
        bcmd_t cmd = bcs->cmd;

        if ((cmd==BC_BLANK) && (priorbcs) && (priorbcs->cmd==BC_DUMP)) {
            stash_address = (void*)dump_block(stash_address, 16);
            break;
        }

        switch (cmd) { //Apply -fjump-tables if you don't have a GOT!!!
            case BC_FILE: {
                store(tok_addr(&stash_address), tok_dec32u());
            } break;
            case BC_JAL: {
                uint32_t address = (uint32_t)tok_addr(&stash_address);
                entry_t start = (entry_t)address;
                start();
            } break;
            case BC_LW: {
                volatile uint32_t* p = tok_addr(&stash_address);

                bufw_hex32u((uint32_t)p);
                uwrite_int8(':');
                bufw_hex32u(*p);
                bufw_newline();
            } break;
            case BC_LHU: {
                volatile uint16_t* p = tok_addr(&stash_address);

                bufw_hex32u((uint32_t)p);
                uwrite_int8(':');
                bufw_hex16u(*p);
                bufw_newline();
            } break;
            case BC_LBU: {
                volatile uint8_t* p = tok_addr(&stash_address);

                bufw_hex32u((uint32_t)p);
                uwrite_int8(':');
                bufw_hex8u(*p);
                bufw_newline();
            } break;
            case BC_SW: {
                uint32_t word = tok_hex32u();
                volatile uint32_t* p = tok_addr(&stash_address);

                *p = word;
            } break;
            case BC_SH: {
                uint16_t half = tok_hex16u();
                volatile uint16_t* p = tok_addr(&stash_address);

                *p = half;
            } break;
            case BC_SB: {
                uint8_t byte = tok_hex8u ();
                volatile uint8_t* p = tok_addr(&stash_address);

                *p = byte;
            } break;

        //COLT45 extensions:
            case BC_DUMP: {
                stash_address = (void*)dump_block(tok_addr(&stash_address), 16);
            } break;
            case BC_COPY: {
                const uint32_t* a_src = tok_addr(&stash_address);
                uint32_t* a_dst = (uint32_t*)tok_hex32u();
                uint32_t l_cpy  = tok_hex32u();

                uint32_t xor = copy_xor(a_src, l_cpy, a_dst);

                bufw_hex32u(xor);
                bufw_newline();
            } break;

        //Graphics commands:
            case BC_GS: {
                const gstate_tp state = GP_STATE;

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
                uwrite_int8s(" gc:"); bufw_hex32u( (uint32_t)gp_argb );
                uwrite_int8s(" sc:"); bufw_hex32u( (uint32_t)sw_argb );
                bufw_newline();
            } break;
            case BC_CC: case BC_SC: case BC_GC: {
                color_t color = (color_t)tok_hex32u();
                if (cmd != BC_GC) sw_argb = color;
                if (cmd != BC_SC) gp_argb = color;
            } break;

            case BC_FF: {
                gframe_pv frame = FRAME_PTR(tok_hex32u());
                PF_FRAME = frame;
                GP_FRAME = frame;
                sw_frame = frame;
            } break;
            case BC_PF: {
                //PF_FRAME = FRAME_PTR(tok_hex32u());
                PF_FRAME = (gframe_pv)tok_hex32u(); //Test hw frame# conversion
            } break;
            case BC_GF: {
                //GP_FRAME = FRAME_PTR(tok_hex32u());
                GP_FRAME = (gframe_pv)tok_hex32u(); //Test hw frame# conversion
            } break;
            case BC_SF: {
                sw_frame = FRAME_PTR(tok_hex32u());
            } break;
            case BC_GP: {
                GP_GCODE = tok_addr(&stash_address);
            } break;

            case BC_FILL: {
                if (gp_argb!=KILLR) hwfill(gp_argb);
                if (sw_argb!=KILLR) swfill(sw_frame, sw_argb);
            } break;
            case BC_LINE: {
                uint16_t x0           = tok_dec16u();
                uint16_t y0           = tok_dec16u();
                uint16_t x1           = tok_dec16u();
                uint16_t y1           = tok_dec16u();
                if (gp_argb!=KILLR) hwline(gp_argb, x0, y0, x1, y1);
                if (sw_argb!=KILLR) swline(sw_frame, sw_argb, x0, y0, x1, y1);
            } break;
            case BC_PIXL: {
                uint16_t x            = tok_dec16u();
                uint16_t y            = tok_dec16u();
                if (gp_argb!=KILLR) hwpixel(gp_argb, x, y);
                if (sw_argb!=KILLR) swpixel(sw_frame, sw_argb, x, y);
            } break;
            case BC_ELIP: {
                uint16_t xc           = tok_dec16u();
                uint16_t yc           = tok_dec16u();
                uint16_t ox           = tok_dec16u();
                uint16_t oy           = tok_dec16u();
                if (gp_argb!=KILLR) hwelipse(gp_argb, xc, yc, ox, oy);
                if (sw_argb!=KILLR) swelipse(sw_frame, sw_argb, xc, yc, ox, oy);
            } break;
            case BC_CIRC: {
                uint16_t x            = tok_dec16u();
                uint16_t y            = tok_dec16u();
                uint16_t r            = tok_dec16u();
                if (sw_argb!=KILLR) swcircle(sw_frame, sw_argb, x, y, r);
            } break;

            BC_BLANK: {
            } break;
            BC_UNKNOWN: {
                uwrite_int8('?');
            } //FALLTHROUGH
            default: { //UNKNOWN: "??" UNIMPLEMENTED/bad-case: "?"
                uwrite_int8('?');
                uwrite_int8s(input);
                bufw_newline();
            } break;
        }
        priorbcs = bcs;
    }

    return 0;
}
