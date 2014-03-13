#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"

//NOTE:Using #define since INLINE functions not making it through CLANG/LLVM -> GAS process

typedef uint32_t color_t;
typedef uint32_t* gframe_p;
typedef uint32_t* gpcode_p;
typedef struct gstate_s {
  uint32_t u32;
} gstate_t;

//MEMORY MAPPED CONTROLS
#define PF_FRAME  (*((volatile gframe_p*) 0x80000050)) //WRITE:PixelFeeder source frame addr/num
#define GP_FRAME  (*((volatile gframe_p*) 0x80000054)) //WRITE:GraphicsProcessor frame addr/num
#define GP_GCODE  (*((volatile gpcode_p*) 0x80000058)) //WRITE:Set code addr & trigger GP now!
#define GP_STATE  (*((volatile gstate_t*) 0x8000005C)) //READ:Status bits/values of PIX,GP,etc.

//MEMORY FIXED GLOBAL TEMPORARIES
#define GPTEMP_PTR ((gpcode_p)0x10003000) //FIXED location "global"
#define GPTEMP_SZW (0x00000020) //32-words is...
#define GPTEMP_SZB (GPTEMP_SZW*4) // (128-bytes)


//Renumbered so FRAME0 is 0x10000000...but usually skip that one!
#define STD_FRAME0X ((gframe_p) 0x10000000)
#define STD_FRAME1  ((gframe_p) 0x10400000)
#define STD_FRAME2  ((gframe_p) 0x10800000)
#define STD_FRAME3  ((gframe_p) 0x10C00000)
#define STD_FRAME4  ((gframe_p) 0x11000000) //...advance 0x0040_0000 each
//...NOTE:Frame# (1,2,3,...) can also be used for PF_FRAME & GP_FRAME


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

#define FRAME_PTR(F)    ( (gframe_p) (                      \
    ((uint32_t)(F) & FPMASK) ? ((uint32_t)(F) & FPMASK)      \
        : (0x10000000 | (((uint32_t)(F) & FNMASK)<<FSHIFT)) ) )

#define PIX_PTR(FP,X,Y) ( (uint32_t*) (                 \
    ((uint32_t)(FP)) | ((Y)<<YSHIFT) | ((X)<<XSHIFT)  ) )


void hwfill  (color_t color);
void hwline  (color_t color,
                uint16_t x0, uint16_t y0,
                uint16_t x1, uint16_t y1);
void hwpixel (color_t color,
                uint16_t x,  uint16_t y);
//void hwcircle(color_t color,
//                uint16_t xc, uint16_t yc,
//                uint16_t r);
void hwelipse(color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t rx, uint16_t ry);


void swfill  (gframe_p frame, color_t color);
void swline  (gframe_p frame, color_t color,
                uint16_t x0, uint16_t y0,
                uint16_t x1, uint16_t y1);
void swpixel (gframe_p frame, color_t color,
                uint16_t x,  uint16_t y);
void swcircle(gframe_p frame, color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t r);
void swelipse(gframe_p frame, color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t rx, uint16_t ry);

void swcircle_old(gframe_p frame, color_t color,
                    uint16_t xc, uint16_t yc,
                    uint16_t r);
void swpixel_4way(uint32_t *fp, color_t color,
                    uint16_t xc, uint16_t yc,
                    int16_t ox, int16_t oy);
void swpixel_8way(uint32_t *fp, color_t color,
                    uint16_t xc, uint16_t yc,
                    int16_t ox, int16_t oy);


// *** GP_GCODE COMMANDs: INST Fields, OpCodes, etc. ***

#define GOP_STOP    ((uint8_t) 0x00)
#define GOP_FILL    ((uint8_t) 0x01)
#define GOP_LINE    ((uint8_t) 0x02)
#define GOP_PIXEL   ((uint8_t) 0x03)
#define GOP_ELIPSE  ((uint8_t) 0x04)

#define CMD_STOP(C)     CMD_rgb(GOP_STOP,   0) //No trailing words
#define CMD_FILL(C)     CMD_rgb(GOP_FILL,   C) //No trailing words
#define CMD_LINE(C)     CMD_rgb(GOP_LINE,   C) //Then 2 x CMD_point
#define CMD_PIXEL(C)    CMD_rgb(GOP_PIXEL,  C) //Then 1 x CMD_point
#define CMD_ELIPSE(C)   CMD_rgb(GOP_ELIPSE, C) //Then 2 x CMD_point
#define CMD_rgb(OP,C)   ((uint32_t) ( (((OP)&0x0FF )<<24 ) | ((C)&0x0FFFFFF) ))
#define CMD_point(X,Y)  ((uint32_t) ( (((X)&(PMASK))<<16 ) | ((Y)&(PMASK))   ))
//efine CMD_point(X,Y)  ((uint32_t) ( (((X)&(PMASK))<<16 ) | ((Y)&(PMASK)) | (T<<31) ))

#endif
