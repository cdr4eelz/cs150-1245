#include "types.h"
#include "graphics.h"

/* This app serves to make pixel-by-pixel comparison between software and hardware
   implementations of each shape. There is no automated comparison, one simply
   flips between frames using the GIOS ("ff <frame#>") commands.*/
//typedef void (*entry_t)(void);

gframe_pv sw_frame;

static void dd_fill(
    color_t color)
{
    swfill(sw_frame,  color);
    hwfill(           color);
}

static void dd_line(
    color_t color,
    uint16_t x0, uint16_t y0,
    uint16_t x1, uint16_t y1)
{
    swline(sw_frame,  color, x0,y0, x1,y1);
    hwline(           color, x0,y0, x1,y1);
}

static void dd_pixl(
    color_t color,
    uint16_t x, uint16_t y)
{
    swline(sw_frame, color, x,y, x,y);
    hwline(          color, x,y, x,y);
}

static void dd_elip(
    color_t color_edge,
    uint16_t xc, uint16_t yc,
    uint16_t a,  uint16_t b,
    color_t color_fill)
{
    swelip(sw_frame,  color_edge, xc,yc, a,b, color_fill);
    hwelip(           color_edge, xc,yc, a,b, color_fill);
}

static void dd_circ(
    color_t color_edge,
    uint16_t xc, uint16_t yc,
    uint16_t r,
    color_t color_fill)
{
    swelip(sw_frame,  color_edge, xc,yc, r,r, color_fill);
    hwelip(           color_edge, xc,yc, r,r, color_fill);
}

static void dd_rect(
    color_t color_edge,
    uint16_t L, uint16_t T,
    uint16_t R,  uint16_t B,
    color_t color_fill)
{
    swrect(sw_frame,  color_edge, L,T, R,B, color_fill);
    hwrect(           color_edge, L,T, R,B, color_fill);
}

int main(int argc, char** argv)
{
    PF_FRAME = STD_FRAME3;

    GP_FRAME = STD_FRAME1;
    sw_frame = STD_FRAME2;
    dd_fill(0x00002233u);
    dd_line(0x00FFFFFFu,  10, 10,  700,300);
    dd_line(0x00FFFFFFu, 400, 10,   10,500);
    dd_pixl(0x00FFFFFFu,  20,250);
    dd_elip(0x00FF0000u, 100,100,   20, 30,  0xFF1A7F0Fu);
    PF_FRAME = STD_FRAME1;
    dd_rect(0x00FFFFFFu, 550,150,  750,250,  0xFFF0F020u);
    dd_circ(0x00000000u, 650,200,   50,      0x00000000u);
    dd_circ(0x00222222u, 650,200,   40,      0x00000000u);
    dd_circ(0x00444444u, 650,200,   30,      0x00000000u);
    dd_circ(0x00AAAAAAu, 650,200,   20,      0xFF000000u);
    dd_circ(0x00DDDDDDu, 650,200,   10,      0x00000000u);
    dd_rect(0x00FFFFFFu, 550,515,  310,333,  0xFFF300F2u);

    GP_FRAME = STD_FRAME3;
    sw_frame = STD_FRAME4;
    dd_fill(0x00FF2222u);
    dd_line(0x0000FF00u,  10, 10,  700,300);
    dd_line(0x000000FFu, 500,250,  200, 90);
    dd_line(0x00000000u,  10,300,  400,500);
    dd_rect(0x00FFFFFFu, 600,400,  799,599,  0xFF000000u);
    dd_rect(0x000000FFu, 700,500,  799,599,  0xFF2F7FFFu);
    dd_rect(0x0000FF00u, 650,450,  699,499,  0xFF2FFF2Fu);
    dd_rect(0x00FF0000u, 625,425,  649,449,  0xFFFF2F2Fu);
    dd_elip(0x00222222u, 200,300,   20, 20,  0x00000000u);
    dd_elip(0x00008844u, 600,300,  100, 50,  0xFF7FFF1Fu);
    dd_pixl(0x00023666u,  21, 51);
    dd_circ(0x00222222u, 650,200,   50,      0x00000000u);

    GP_WAIT();
    PF_FRAME = STD_FRAME3;

//NOTE:start.s for target now handles jump to bios upon exit
//    uint32_t bios = ascii_hex_to_uint32("40000000");
//    entry_t start = (entry_t) (bios);
//    start();
    return 0;
}
