#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"

// DVI Mode: VESA 800x600 pixels @72Hz
#define PIX_SIZEB     (4)
#define COL_SIZEP     (0x0320)      //800P
#define COL_SIZEB     (4*COL_SIZEP)             //3200B (0x0C80)
#define COL_OFFSETP   (0x0001)      //1P
#define COL_OFFSETB   (4*COL_OFFSETP)           //4B
#define COL_LASTP     (COL_SIZEP-1)       //800P-1P=799P
#define COL_LASTB     (4*COL_LASTP)   //3196B (0x0C7C)
#define ROW_SIZEP     (0x0258)      //600P
#define ROW_SIZEB     (4*ROW_SIZEP)             //2400KB (0x00258000) ???
#define ROW_LASTP     (ROW_SIZEP-1)       //600P-1P=599P
#define ROW_LASTB     (0x00257000)    //2396KB (0x00257000)
#define ROW_OFFSETC   (0x0400)      //1KC
#define ROW_OFFSETP   (ROW_OFFSETC*COL_OFFSETP)               //1KP   (0x0400)
#define ROW_OFFSETB   (4*ROW_OFFSETP) //4KB   (0x1000)
#define ROW_XTRAP     (ROW_OFFSETP-COL_SIZEP)       //1KP-800P= 224P  (0xE0)
#define FRAME_SIZEP   (COL_SIZEP*ROW_SIZEP)                   //480KP (0x00075300)
#define FRAME_SIZEB   (4*ROW_SIZEP) //2400KB (0x00258000) ???
#define FRAME_OFFSETR (0x0400)      //1KR
#define FRAME_OFFSETP (FRAME_OFFSETR*ROW_OFFSETC*COL_OFFSETP) //1MP   (0x00100000)
#define FRAME_OFFSETB (0x00400000)    //4MB (0x00400000)
#define FRAME_XTRAR  (FRAME_OFFSETR-ROW_SIZEP)     //1KR-600P= 424P  (0x1A8)
#define FRAME_XTRAP  (FRAME_OFFSETP-x)     //1MP-600P= 424P  (0x...)
#define PIX_SIZEF   (4*FRAME_SIZEP) //2400KB (0x00258000)
#define PIX_LASTB     (0x00257C7C)    //2396KB+3196B (0x00257C7C)
#define PIX_XTRAP  (Ay+Bx-AB)     //1MP-600P= 424P  (0x...)

struct __attribute__ ((aligned (4))) __attribute__ ((packed)) gstate_s {
/* assign graphics_status = {
        2'b00, pf_feedframe[5:0],
        8'b0000_0000, //Maybe for overlay stuff later
        2'b00, gp_procframe[5:0], //TODO:Count video_xyz activity, not snapshot
        video_ready, video_valid, 3'b00_0, line_ready, filler_ready, gp_ready
}; */
    int unused_1:2; unsigned int pf_feedframe:6;
    int unused_2:8;
    int unused_3:2; unsigned int gp_procframe:6;
    BOOL video_ready:1; BOOL video_valid:1;
        int unused_4:3;
            BOOL line_ready:1; BOOL filler_ready:1; BOOL gp_ready:1;
};
typedef union gstate_u {
    uint32_t u32;
    struct gstate_s f;
} gstate_tp, *gstate_pp;
typedef gstate_tp volatile gstate_tv, *gstate_pv;

typedef uint32_t color_t, *color_p;
typedef uint32_t pixel_tp, *pixel_pp;
typedef pixel_tp volatile pixel_tv, *pixel_pv;
typedef struct grow_s {
    pixel_tp used[COL_SIZEP];
    pixel_tp xtra[ROW_XTRAP];
} grow_tp, *grow_pp;
typedef volatile grow_tp grow_tv, *grow_pv;
typedef struct gframe_sx {
    grow_tp used[ROW_SIZEP];
    grow_tp xtra[FRAME_XTRAR];
} gframe_tp, *gframe_pp;
typedef volatile gframe_tp gframe_tv, *gframe_pv;

typedef uint32_t* gpcode_pp;
#define XSHIFT  (2)
#define YSHIFT  (12)
#define FSHIFT  (22)
#define PMASK   (0x03FF)        //10-bit pixel coordinate (before shifting into place)
#define XMASK   (0x00000FFC)    //10-bits shifted into "x" coordinate
#define YMASK   (0x003FF000)    //10-bits shifted into "y" coordinate
#define FPMASK  (0xFFC00000)    //Upper nibble plus 6-bits for frame#
#define FNMASK  (0x0000003F)    //Just the 6-bits for frame# (before shifting)
typedef volatile gpcode_pp gpcode_pv;


//Renumbered so FRAME0 is 0x10000000...but usually skip that one!
#define STD_FRAME0X ((gframe_pv) 0x10000000)
#define STD_FRAME1  ((gframe_pv) 0x10400000)
#define STD_FRAME2  ((gframe_pv) 0x10800000)
#define STD_FRAME3  ((gframe_pv) 0x10C00000)
#define STD_FRAME4  ((gframe_pv) 0x11000000) //...advance 0x0040_0000 each
//...NOTE:Frame# (1,2,3,...) can also be used for PF_FRAME & GP_FRAME

//MEMORY MAPPED CONTROLS
#define PF_FRAME  (*((gframe_pv volatile *)0x80000050)) //WRITE:PixelFeeder source frame addr/num
#define GP_FRAME  (*((gframe_pv volatile *)0x80000054)) //WRITE:GraphicsProcessor frame addr/num
#define GP_GCODE  (*((gpcode_pv volatile *)0x80000058)) //WRITE:Set code-addr, trigger GP now!
#define GP_STATE  (*((gstate_pv)0x8000005C)) //READ:Status of PIX,GP,etc.

//MEMORY FIXED GLOBAL TEMPORARIES
#define GPTEMP_PTR    ((gpcode_pv)0x10003000) //FIXED location "global"
#define GPTEMP_SZW    (0x00000020)           //  32-words is...
#define GPTEMP_SZB    ((GPTEMP_SZW) << 2)   //  128-bytes

#define PIX_PTR(FP,X,Y) ( (pixel_pv) (                    \
    ((uint32_t)(FP)) | ((Y)<<(YSHIFT)) | ((X)<<(XSHIFT)) ) )

#define FRAME_PTR(F)  ( std_frame((uint32_t)(F)) )

#define GP_READY()    ((BOOL)((GP_STATE.f.gp_ready) ? TRUE : FALSE))
#define GP_WAIT()     do {} while (!GP_READY())

gframe_pv std_frame(uint32_t fn_or_fp);

void hwfill  (color_t color);
void hwline  (color_t color,
                uint16_t x0, uint16_t y0,
                uint16_t x1, uint16_t y1);
void hwpixel (color_t color,
                uint16_t x,  uint16_t y);
void hwelipse(color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t rx, uint16_t ry);


void swfill  (gframe_pv frame, color_t color);
void swline  (gframe_pv frame, color_t color,
                uint16_t x0, uint16_t y0,
                uint16_t x1, uint16_t y1);
void swpixel (gframe_pv frame, color_t color,
                uint16_t x,  uint16_t y);
void swcircle(gframe_pv frame, color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t r);
void swelipse(gframe_pv frame, color_t color,
                uint16_t xc, uint16_t yc,
                uint16_t rx, uint16_t ry);

void swcircle_old(gframe_pv frame, color_t color,
                    uint16_t xc, uint16_t yc,
                    uint16_t r);
void swpixel_4way(gframe_pv fp, color_t color,
                    uint16_t xc, uint16_t yc,
                    uint16_t ox, uint16_t oy);
void swpixel_8way(gframe_pv fp, color_t color,
                    uint16_t xc, uint16_t yc,
                    uint16_t ox, uint16_t oy);


// *** GP_GCODE COMMANDs: INST Fields, OpCodes, etc. ***

#define GOP_STOP    ((uint8_t) 0x00)
#define GOP_FILL    ((uint8_t) 0x01)
#define GOP_LINE    ((uint8_t) 0x02)
#define GOP_PIXEL   ((uint8_t) 0x03)
#define GOP_ELIPSE  ((uint8_t) 0x04)

#define CMD_STOP()      CMD_rgb(GOP_STOP,   0    ) //No trailing words
#define CMD_FILL(C)     CMD_rgb(GOP_FILL,   C.u32) //No trailing words
#define CMD_LINE(C)     CMD_rgb(GOP_LINE,   C.u32) //Then 2 x CMD_point
#define CMD_PIXEL(C)    CMD_rgb(GOP_PIXEL,  C.u32) //Then 1 x CMD_point
#define CMD_ELIPSE(C)   CMD_rgb(GOP_ELIPSE, C.u32) //Then 2 x CMD_point
#define CMD_rgb(OP,U24) ((uint32_t) ( (((OP)&0x0FF )<<24 ) | ((U24)&0x0FFFFFF) ))
#define CMD_point(X,Y)  ((uint32_t) ( (((X)&(PMASK))<<16 ) | ((Y)&(PMASK))   ))
//efine CMD_point(X,Y)  ((uint32_t) ( (((X)&(PMASK))<<16 ) | ((Y)&(PMASK)) | (T<<31) ))

#endif
