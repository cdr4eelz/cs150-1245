#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"


//MEMORY MAPPED CONTROLS
#define PF_FRAME    (*((volatile uint32_t*) 0x80000050))
#define GP_FRAME    (*((volatile uint32_t*) 0x80000054))
#define GP_CODE     (*((volatile uint32_t*) 0x80000058))
//#define GP_CONTROL  (*((volatile uint32_t*) 0x8000005C)) //Status of GP & friends


//Rebased so FRAME0 would be 0x10000000...but skip that one!
#define STD_FRAME1  ((uint32_t*) 0x10400000)
#define STD_FRAME2  ((uint32_t*) 0x10800000)
#define STD_FRAME3  ((uint32_t*) 0x10C00000) //...advance 0x0040_0000 each
//...NOTE:Frame# (1,2,3,etc.) can be used instead in PF_FRAME & GP_FRAME


// DVI Mode: VESA 800x600 pixels @72Hz
#define COL_SIZEP       (0x0320)        //800
#define ROW_SIZEP       (0x0258)        //600
#define COL_OFFSETP     (0x00000001)    //1
#define ROW_OFFSETP     (0x00000400)    //1 K
#define FRAME_OFFSETP   (0x00100000)    //1 M
#define COL_OFFSETB     (0x00000004)    //4
#define COL_LASTB       (0x00000C7C)    //3196
#define COL_SIZEB       (0x00000C80)    //3200
#define ROW_OFFSETB     (0x00001000)    //4 K
#define ROW_LASTB       (0x00257000)    //2396 K
#define ROW_SIZEB       (0x00258000)    //2400 K
#define PIX_LASTB       (0x00257C7C)    //2396 K + 3196
#define FRAME_OFFSETB   (0x00400000)    //4 M
#define XSHIFT  (2)
#define YSHIFT  (12)
#define FSHIFT  (22)
#define PMASK   (0x03FF)        //10-bit pixel coordinate (before shifting into place)
#define XMASK   (0x00000FFC)    //10-bits shifted into "x" coordinate
#define YMASK   (0x003FF000)    //10-bits shifted into "y" coordinate
#define FPMASK  (0xFFC00000)    //Upper nibble plus 6-bits for frame#
#define FNMASK  (0x0000003F)    //Just the 6-bits for frame# (before shifting)

#define FRAME_PTR(F)    ( (uint32_t*) (                 \
    ((F) & FPMASK) ? ((F) & FPMASK)                     \
        : (0x10000000 | (((F) & FNMASK)<<FSHIFT))     ) )

#define FRAME_NUM(F)    ( (uint32_t)                    \
    ((F) & FPMASK) ? (((F)>>FSHIFT) & FPMASK) : F       )

#define PIX_PTR(FP,Y,X) ( (uint32_t*) (                 \
    ((uint32_t)(FP)) | ((Y)<<YSHIFT) | ((X)<<XSHIFT)  ) )

#define PIX_PTC(F,Y,X) ( (uint32_t*) (                  \
    (FRAME_NUM(F)<<FSHIFT) | (((Y) & PMASK)<<YSHIFT)    \
    | (((X) & PMASK)<<XSHIFT)                         ) )


void swfill(uint32_t color, uint32_t frame);
void swline(uint32_t color, uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint32_t frame);
void swpixel(uint32_t color, uint16_t x, uint16_t y, uint32_t frame);
#define SWPIXEL(C,X,Y,F) \
    { *PIX_PTC((uint32_t)(F),(uint16_t)(Y), (uint16_t)(X)) = (uint32_t)(C); }

void hwfill(uint32_t color, uint32_t frame);
void hwline(uint32_t color, uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint32_t frame);
void hwpixel(uint32_t color, uint16_t x, uint16_t y, uint32_t frame);


//GP COMMANDS
#define OP_STOP     ((uint8_t) 0x00)
#define OP_FILL     ((uint8_t) 0x01)
#define OP_LINE     ((uint8_t) 0x02)
#define OP_PIXEL    ((uint8_t) 0x03)
#define OMASK       (0xFF)
#define CMASK       (0x00FFFFFF)

#define cmd_COLOR(OP,C)     ((uint32_t) ( (((OP) & OMASK)<<24) | ((C) & CMASK) ))
#define cmd_POINT(X,Y,T)    ((uint32_t) ( (((X) & PMASK)<<16) | ((Y) & PMASK) | (T<<31) ))
#define CMD_STOP(C)         ((uint32_t) 0)          //No trailing words
#define CMD_FILL(C)         cmd_COLOR(OP_FILL, C)   //No trailing words
#define CMD_LINE(C)         cmd_COLOR(OP_LINE, C)   //Then 2 x cmd_POINT
#define CMD_PIXEL(C)        cmd_COLOR(OP_PIXEL, C)  //Then 1 x cmd_POINT

#endif
