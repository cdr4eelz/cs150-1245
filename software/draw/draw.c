#include "types.h"
#include "graphics.h"

//typedef void (*entry_t)(void);

int main(int argc, char** argv) {
    gframe_pv sw_frame;

    PF_FRAME = STD_FRAME3;

    GP_FRAME = STD_FRAME1;
    sw_frame = STD_FRAME2;
    hwfill  (           0x00002233);
    swfill  (sw_frame,  0x00002233);
    hwline  (           0xFFFFFFFF,  10, 10,  700,300);
    swline  (sw_frame,  0xFFFFFFFF,  10, 10,  700,300);
    hwline  (           0xFFFFFFFF, 400, 10,   10,500);
    swline  (sw_frame,  0xFFFFFFFF, 400, 10,   10,500);
    hwpixel (           0xFFFFFFFF,  20,250);
    swpixel (sw_frame,  0xFFFFFFFF,  20,250);
    hwelipse(           0x00FF0000, 300,300,   50, 50);
    swelipse(sw_frame,  0x00FF0000, 300,300,   50, 50);
    PF_FRAME = STD_FRAME1;
    swcircle_old(sw_frame, 0x00000000, 650,200,   50);
    swcircle_old(sw_frame, 0x00222222, 650,200,   40);
    swcircle_old(sw_frame, 0x00444444, 650,200,   30);
    swcircle_old(sw_frame, 0x00666666, 650,200,   20);
    swcircle_old(sw_frame, 0x00888888, 650,200,   10);

    GP_FRAME = STD_FRAME3;
    sw_frame = STD_FRAME4;
    hwfill  (           0x00FF2222);
    swfill  (sw_frame,  0x00FF2222);
    hwline  (           0x0000FF00,  10, 10,  700,300);
    swline  (sw_frame,  0x0000FF00,  10, 10,  700,300);
    hwline  (           0x000000FF, 500,250,  200, 90);
    swline  (sw_frame,  0x000000FF, 500,250,  200, 90);
    hwline  (           0x00000000,  10,300,  400,500);
    swline  (sw_frame,  0x00000000,  10,300,  400,500);
    hwelipse(           0x22222222, 650,200,   50, 50);
    swcircle(sw_frame,  0x22222222, 650,200,   50);
    hwelipse(           0x00008844, 250,120,  100, 25);
    swelipse(sw_frame,  0x00008844, 250,120,  100, 25);
    hwpixel (           0x00023666,  21, 51);
    swpixel (sw_frame,  0x00023666,  21, 51);

    PF_FRAME = STD_FRAME4;
//    uint32_t bios = ascii_hex_to_uint32("40000000");
//    entry_t start = (entry_t) (bios);
//    start();
    return 0;
}
