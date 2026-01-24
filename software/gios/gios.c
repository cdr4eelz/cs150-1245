#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory.h"
#include "parse.h"
#include "graphics.h"

#define BUFFER_LEN (0x00000080) //128-bytes

#define VERSION_I 1
#define VERSION_C ('0' + VERSION_I) //Turn into '<version>' char
#define VERSION_S STIFIE(VERSION_I) //Turn into "<version>" const string
#define STIFIE(Z) STIFIY(Z) //Stringify expanded macro value of Z
#define STIFIY(z) #z        //Stringify argument z

#define KILLR 0xFFFFFFFF

typedef void (*entry_t)(void);


int main( void )
{
    uwrite_int8s("\r\n\r\n[Golt45.2." VERSION_S "]\r\n\r\n");

    int8_t      buffer[BUFFER_LEN];
    void*       stash_address   = (void*)0x10000000;
    uint32_t    last_result = 0xFFFFFFFF;
    bcmdspec_t* last_bcs  = NULL;
    color_t     sw_color = (color_t)0x4044FFAA;
    color_t     hw_color = (color_t)0xC044AAFF;
    gframe_pv   sw_frame = STD_FRAME1;

    GP_FRAME = STD_FRAME1;

    for ( ; ; ) forever: {
        uwrite_int8('>'); uwrite_int8(' ');
        int8_t* input = read_token(buffer, BUFFER_LEN, NULL);
        bcmdspec_t* bcs = token_cmdspec(input);
        bcmd_t cmd = bcs->cmd;
        uint16_t flags = bcs->flags;
        uint16_t gflag = flags;
        if (!gflag) {
            if (hw_color!=KILLR) gflag |= 2;
            if (sw_color!=KILLR) gflag |= 1;
        }

        if ((cmd==BC_BLANK) && (last_bcs) && (last_bcs->cmd==BC_DUMP)) {
            stash_address = (void*)dump_block(stash_address, 16, last_bcs->flags & 0x01);
            continue;
        }

        switch (cmd) { //WARN:Must use -fno-jump-tables or ensure GOT&GP in LD-script!!!
            case BC_FILE: {
                last_result = store_xor(tok_addr(&stash_address), tok_dec32u());
            } break;

            case BC_JAL: {
                entry_t start = (entry_t)(uint32_t)tok_addr(&stash_address);
                start(); //The double-cast above avoids a "pedantic" warning
//void *ptr = (void *)0x1234567; Use this to for true jump rather than call...
//goto *ptr; // This is a GNU C extension, not standard C.
            } break;

            case BC_LOAD: {
                radixize_t rz = flags;
                void* p       = tok_addr(&stash_address);
                uint32_t u32  = 0;

                switch (flags) {
                    case RZ_HEX32: u32 = *((uint32_t*)p); break;
                    case RZ_HEX16: u32 = *((uint16_t*)p); break;
                    case  RZ_HEX8: u32 = *(( uint8_t*)p); break;
                    default: goto forever;
                }

                bufw_hex32u((uint32_t)p);
                uwrite_int8(':'); uwrite_int8(' ');
                bufw_radnum(rz, u32);
                bufw_newline();
            } break;

            case BC_STORE: {
                radixize_t rz = flags;
                uint32_t u32  = tok_radnum(rz);
                void* p       = tok_addr(&stash_address);

                switch (flags) {
                    case RZ_HEX32: *((uint32_t*)p) = u32; break;
                    case RZ_HEX16: *((uint16_t*)p) = u32; break;
                    case  RZ_HEX8: *(( uint8_t*)p) = u32; break;
                    default: goto forever;
                }
            } break;

        //COLT45 extensions:
            case BC_HELP: {
                bufw_cmdspec();
            } break;

            case BC_RESULT: {
                bufw_hex32u(last_result);
                bufw_newline();
            } break;

            case BC_DUMP: {
                stash_address = (void*)dump_block(tok_addr(&stash_address), 16, last_bcs->flags & 0x01);
            } break;

            case BC_COPY: {
                const uint32_t* a_src = tok_addr(&stash_address);
                uint32_t*       a_dst = (uint32_t*)tok_hex32u();
                uint32_t        l_cpy = tok_hex32u();

                last_result = copy_xor(a_src, l_cpy, a_dst);

                bufw_hex32u(last_result);
                bufw_newline();
            } break;

        //Graphics commands:
            case BC_GSTAT: {
                const gstate_tp stat = GP_STATE;

                bufw_hex32u( stat.u32 );
                uwrite_int8s(" PF#"); bufw_hex8u( stat.f.pf_feedframe );
                uwrite_int8('-');
                uwrite_int8( (stat.f.pf_dormant)   ? 'D' : 'd');
                uwrite_int8( (stat.f.pf_fault)     ? '*' : ' ');
                uwrite_int8s(" GF#"); bufw_hex8u( stat.f.gp_procframe );
                uwrite_int8('-');
                uwrite_int8( (stat.f.elipse_ready) ? 'E' : 'e');
                uwrite_int8( (stat.f.line_ready)   ? 'L' : 'l');
                uwrite_int8( (stat.f.filler_ready) ? 'F' : 'f');
                uwrite_int8( (stat.f.gp_ready)     ? 'G' : 'g');
                uwrite_int8( (stat.f.gp_fault)     ? '*' : ' ');
                uwrite_int8s(" SF:"); bufw_hex32u( (uint32_t)sw_frame );
                bufw_newline();
                uwrite_int8s(" hw:"); bufw_hex32u( (uint32_t)hw_color );
                uwrite_int8s(" sw:"); bufw_hex32u( (uint32_t)sw_color );
                bufw_newline();
            } break;

            case BC_GCODE: {
                GP_GCODE = tok_addr(&stash_address);
            } break;

            case BC_FRAME: {
                gframe_pv frame = tok_addr(&stash_address);
                if (flags & 0x04) PF_FRAME = frame; //Test hw frame# conversion
                frame = FRAME_PTR(frame); //Software converted frame#
                if (flags & 0x02) GP_FRAME = frame;
                if (flags & 0x01) sw_frame = frame;
            } break;

            case BC_BACK: {
                color_t color = (color_t)tok_hex32u();
                hwback(color);
            } break;

            case BC_CLIP: {
                uint32_t parms = tok_hex32u();
                uint16_t L  = tok_dec16u();
                uint16_t T  = tok_dec16u();
                uint16_t R  = tok_dec16u();
                uint16_t B  = tok_dec16u();
                hwclip(parms, L,T, R,B);
            } break;

        //HW/SW common commands:
            case BC_COLOR: {
                color_t color = (color_t)tok_hex32u();
                if (flags & 0x02) hw_color = color;
                if (flags & 0x01) sw_color = color;
            } break;

            case BC_FILL: {
                if (gflag & 0x02) hwfill(hw_color);
                if (gflag & 0x01) swfill(sw_frame, sw_color);
            } break;

            case BC_LINE: {
                uint16_t x0 = tok_dec16u();
                uint16_t y0 = tok_dec16u();
                uint16_t x1 = tok_dec16u();
                uint16_t y1 = tok_dec16u();
                if (gflag & 0x02) hwline(hw_color, x0,y0, x1,y1);
                if (gflag & 0x01) swline(sw_frame, sw_color, x0,y0, x1,y1);
            } break;

            case BC_PIXL: {
                uint16_t x  = tok_dec16u();
                uint16_t y  = tok_dec16u();
                if (gflag & 0x02) hwline(hw_color, x,y, x,y);
                if (gflag & 0x01) swpixl(sw_frame, sw_color, x,y);
            } break;

            case BC_ELIP: {
                uint16_t xc = tok_dec16u();
                uint16_t yc = tok_dec16u();
                uint16_t a  = tok_dec16u();
                uint16_t b  = tok_dec16u();
                if (gflag & 0x02) hwelip(hw_color, xc,yc, a,b);
                if (gflag & 0x01) swelip(sw_frame, sw_color, xc,yc, a,b);
            } break;

        //Misc. commands:
            BC_UNKNOWN: {
                uwrite_int8('?');
            }
            /* no break */
            default: { //UNKNOWN: "?<>?" UNIMPLEMENTED/bad-case: "<>?"
                uwrite_int8s(input);
                uwrite_int8('?');
            }
            /* no break */
            BC_BLANK: {
                bufw_newline();
            } break;
        }
        last_bcs = bcs;
    }

    uwrite_int8s("\r\n\r\n[EXIT-BIOS!]\r\n\r\n");
    return 0;
}
