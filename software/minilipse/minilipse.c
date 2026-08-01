#include "types.h"
#include "graphics.h"

//typedef void (*entry_t)(void);

gframe_pv sw_frame;

int main(int argc, char** argv)
{
    sw_frame = std_frame(6);
    PF_FRAME = sw_frame;
    GP_FRAME = sw_frame;

    swfill(sw_frame, 0x000022FF);
    swelip(sw_frame, 0x00FF8844, 300,300, 5,25);
    swelip(sw_frame, 0x00FF8800, 400,400, 25,5);
    swelip(sw_frame, 0x0044FF44, 200,200, 60,90);
    swelip(sw_frame, 0x00222244, 100,100, 90,60);

    GP_WAIT();
    return 0;
}
