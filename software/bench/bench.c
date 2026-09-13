#include "types.h"
#include "graphics.h"
#include "mmio_intr_cop0.h"
#include "ascii.h"
#include "benchmark.h"


//typedef void (*entry_t)(void);

//TODO: Move these macros into "graphics.h"
#define hwpixl(      color,x,y) \
            hwline(        (color), (x),(y), (x),(y))
#define swcirc(frame,color,xc,yc,r) \
            swelip((frame),(color),(xc),(yc),(r),(r))
#define hwcirc(      color,xc,yc,r) \
            hwelip(        (color),(xc),(yc),(r),(r))

void sw_draw(void) {
    gframe_pv sw_frame = STD_FRAME1;
    swfill(sw_frame, 0x10002233);
    swline(sw_frame, 0x10FFFFFF,  10, 10,  700,300);
    swline(sw_frame, 0x10FFFFFF,  10, 10,  700,300);
    swline(sw_frame, 0x10FFFFFF, 400, 10,   10,500);
    swpixl(sw_frame, 0x10FFFFFF,  20,250);
    swelip(sw_frame, 0x10FF0000, 100,100,   20, 30);
    swcirc(sw_frame, 0x11000000, 650,200,   50);
    swcirc(sw_frame, 0x12222222, 650,200,   40);
    swcirc(sw_frame, 0x11444444, 650,200,   30);
    swcirc(sw_frame, 0x12666666, 650,200,   20);
    swcirc(sw_frame, 0x11888888, 650,200,   10);

    sw_frame = STD_FRAME3;
    swfill(sw_frame, 0x20FF2222);
    swline(sw_frame, 0x2000FF00,  10, 10,  700,300);
    swline(sw_frame, 0x200000FF, 500,250,  200, 90);
    swline(sw_frame, 0x20000000,  10,300,  400,500);
    swelip(sw_frame, 0x20222222, 200,300,   20, 20);
    swelip(sw_frame, 0x20008844, 600,300,  100, 50);
    swpixl(sw_frame, 0x20023666,  21, 51);
    swcirc(sw_frame, 0x22222222, 650,200,   50);
}


//TODO: Turn this into a GPU sequence of instructions (must be in DDR2 RAM)...
void hw_draw(void) {
    GP_FRAME = STD_FRAME2;
    hwfill(0x10002233);
    hwline(0x10FFFFFF,  10, 10,  700,300);
    hwline(0x10FFFFFF, 400, 10,   10,500);
    hwpixl(0x10FFFFFF,  20,250);
    hwelip(0x10FF0000, 100,100,   20, 30);
    hwcirc(0x11000000, 650,200,   50);
    hwcirc(0x12222222, 650,200,   40);
    hwcirc(0x11444444, 650,200,   30);
    hwcirc(0x12666666, 650,200,   20);
    hwcirc(0x11888888, 650,200,   10);

    GP_FRAME = STD_FRAME4;
    hwfill(0x20FF2222);
    hwline(0x2000FF00,  10, 10,  700,300);
    hwline(0x200000FF, 500,250,  200, 90);
    hwline(0x20000000,  10,300,  400,500);
    hwelip(0x20222222, 200,300,   20, 20);
    hwelip(0x20008844, 600,300,  100, 50);
    hwpixl(0x20023666,  21, 51);
    hwcirc(0x22222222, 650,200,   50);
}

void main()
{
    ISR_STATUS(0,0); // Disable all interrupts

    PF_FRAME = STD_FRAME1;
    sw_draw(); //TODO: Repeat this a large number of times and time it
    hw_draw(); //TODO: Repeat and time total but also...
    GP_WAIT(); //      ...time the wait separately as available CPU time.

    // Return should let "start" code re-launch BIOS
}
