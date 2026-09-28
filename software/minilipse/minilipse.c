#include "types.h"
#include "graphics.h"

//typedef void (*entry_t)(void);

gframe_pv sw_frame;

int main(int argc, char** argv)
{
    sw_frame = std_frame(6);
    PF_FRAME = sw_frame;
    GP_FRAME = sw_frame;

    swfill(sw_frame, 0x000022FFu);
    swelip(sw_frame, 0x00FF8844u, 300,300,  5,25, 0x00000000);
    swelip(sw_frame, 0x00FF8800u, 400,400, 25, 5, 0x00000000);
    swelip(sw_frame, 0x0044FF44u, 200,200, 60,90, 0xFF00FF00);
    swelip(sw_frame, 0x00222244u, 100,100, 90,60, 0xFF000000);

    GP_WAIT();
    return 0;
}
