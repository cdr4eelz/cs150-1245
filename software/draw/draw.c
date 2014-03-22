#include "types.h"
#include "graphics.h"

//typedef void (*entry_t)(void);

gframe_pv sw_frame;

static void dd_fill(color_t color)
{
    swfill(sw_frame,  color);
    hwfill(           color);
}

static void dd_line(color_t color,
          uint16_t x0, uint16_t y0,
          uint16_t x1, uint16_t y1)
{
    swline(sw_frame,  color, x0,y0, x1,y1);
    hwline(           color, x0,y0, x1,y1);
}

static void dd_pixel(color_t color,
                  uint16_t x, uint16_t y)
{
    swpixel(sw_frame,  color, x,y);
//  hwpixel(           color, x,y);
}

static void dd_elipse(color_t color,
                   uint16_t xc, uint16_t yc,
                   uint16_t rx, uint16_t ry)
{
    swelipse(sw_frame,  color, xc,yc, rx,ry);
//  hwelipse(           color, xc,yc, rx,ry);
}

static void dd_circle(color_t color,
          uint16_t xc, uint16_t yc, uint16_t r)
{
    swcircle(sw_frame,  color, xc,yc, r);
//  hwelipse(           color, xc,yc, r,r);
}

int main(int argc, char** argv)
{
    PF_FRAME = STD_FRAME3;

    GP_FRAME = STD_FRAME1;
    sw_frame = STD_FRAME2;
    dd_fill  (0x10002233);
    dd_line  (0x10FFFFFF,  10, 10,  700,300);
    dd_line  (0x10FFFFFF, 400, 10,   10,500);
    dd_pixel (0x10FFFFFF,  20,250);
    dd_elipse(0x10FF0000, 100,100,   10, 10);
    PF_FRAME = STD_FRAME1;
    swcircle_old(sw_frame, 0x11000000, 650,200,   50);
    swcircle    (sw_frame, 0x12222222, 650,200,   40);
    swcircle_old(sw_frame, 0x11444444, 650,200,   30);
    swcircle    (sw_frame, 0x12666666, 650,200,   20);
    swcircle_old(sw_frame, 0x11888888, 650,200,   10);

    GP_FRAME = STD_FRAME3;
    sw_frame = STD_FRAME4;
    dd_fill  (0x20FF2222);
    dd_line  (0x2000FF00,  10, 10,  700,300);
    dd_line  (0x200000FF, 500,250,  200, 90);
    dd_line  (0x20000000,  10,300,  400,500);
    dd_elipse(0x20222222, 200,300,   20, 20);
    dd_elipse(0x20008844, 600,300,  100, 50);
    dd_pixel (0x20023666,  21, 51);
    dd_circle(0x22222222, 650,200,   50);

    PF_FRAME = STD_FRAME4;
//NOTE:start.s for target now handles jump to bios upon exit
//    uint32_t bios = ascii_hex_to_uint32("40000000");
//    entry_t start = (entry_t) (bios);
//    start();
    return 0;
}
