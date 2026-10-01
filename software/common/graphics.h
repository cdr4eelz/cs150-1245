#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"
#include "mmio_intr_cop0.h"

//MEMORY MAPPED CONTROLS (defined here because structs are unique to graphics.h)
#define PF_FRAME  (*((gframe_pv volatile *)MM_PF_FRAME)) //WRITE:PixelFeeder source frame addr/num
#define GP_FRAME  (*((gframe_pv volatile *)MM_GP_FRAME)) //WRITE:GraphicsProcessor frame addr/num
#define GP_GCODE  (*((gpcode_p  volatile *)MM_GP_GCODE)) //WRITE:Set code-addr, trigger GP now!
#define GP_STATE  (*((gstate_pv           )MM_GP_STATE)) //READ:Status of PIX,GP,etc.

//MEMORY FIXED GLOBAL TEMPORARIES
//TODO: Allow dynamic location/size for temp GP commands (or map into BRAM, not DDR memory)
#define GPTEMP_PTR    ((gpcode_p)0x12003000) //FIXED location "global" within DDR2 memory for GP commands
#define GPTEMP_SZW    (0x00000020)          //  32-words is...
#define GPTEMP_SZB    ((GPTEMP_SZW) << 2)  //  128-bytes
#define GPTEMP_BIG    (GPTEMP_PTR+GPTEMP_SZW) //Huge spot to store long runs of GP Commands

// DVI Mode: VESA 800x600 pixels @60Hz (***INCOMPLETE/INCORRECT***)
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
#define FRAME_SIZEB   (4*ROW_SIZEP) //2400KB (0x00258000) ??? HUH??????
#define FRAME_OFFSETR (0x0400)      //1KR
#define FRAME_OFFSETP (FRAME_OFFSETR*ROW_OFFSETC*COL_OFFSETP) //1MP   (0x00100000)
#define FRAME_OFFSETB (0x00400000)    //4MB (0x00400000)
#define FRAME_XTRAR  (FRAME_OFFSETR-ROW_SIZEP)     //1KR-600P= 424P  (0x1A8)
#define FRAME_XTRAP  (FRAME_OFFSETP-x)     //1MP-600P= 424P  (0x...)
#define PIX_SIZEF   (4*FRAME_SIZEP) //2400KB (0x00258000)
#define PIX_LASTB     (0x00257C7C)    //2396KB+3196B (0x00257C7C)
#define PIX_XTRAP  (Ay+Bx-AB)     //1MP-600P= 424P  (0x...)

struct __attribute__ ((aligned (4), packed)) gstate_s {
/*  assign graphics_status = {
        pf_fault, pf_dormant, pf_feedframe[5:0],
        8'b0000_0000, //Maybe for overlay stuff later
        gp_fault, 1'b0, gp_procframe[5:0],
        4'b0000, elip_ready, line_ready, filler_ready, gp_ready
    }; */
    unsigned pf_fault:1;
        unsigned pf_dormant:1;
        unsigned pf_feedframe:6;    //End Byte#1
    unsigned UNUSED_1a:8;           //End Byte#2
    unsigned gp_fault:1;
        unsigned UNUSED_2a:1;
        unsigned gp_procframe:6;    //End Byte#3
    unsigned UNUSED_3a:3;
        unsigned rectangle_ready:1;
        unsigned elipse_ready:1;
        unsigned line_ready:1;
        unsigned filler_ready:1;
        unsigned gp_ready:1;        //End Byte#4
};
typedef union gstate_u {
    uint32_t u32;
    struct gstate_s f;
} gstate_tp, *gstate_pp;
typedef gstate_tp volatile gstate_tv, *gstate_pv;

#define GP_READY()    (GP_STATE.f.gp_ready)
#define GP_WAIT()     do {} while (!GP_READY())


typedef uint32_t color_t, *color_p;
typedef uint32_t pixel_tp, *pixel_pp;
typedef pixel_tp volatile pixel_tv, *pixel_pv;
typedef struct grow_s {
    pixel_tp uc[COL_SIZEP];
    pixel_tp xc[ROW_XTRAP];
} grow_tp, *grow_pp;
typedef volatile grow_tp grow_tv, *grow_pv;
typedef struct gframe_sx {
    grow_tp ur[ROW_SIZEP];
    grow_tp xr[FRAME_XTRAR];
} gframe_tp, *gframe_pp;
typedef volatile gframe_tp gframe_tv, *gframe_pv;

//Renumbered so FRAME0 is 0x10000000...but usually skip that one excetp for fun!
#define STD_FRAME0X ((gframe_pv) 0x10000000)
#define STD_FRAME1  ((gframe_pv) 0x10400000)
#define STD_FRAME2  ((gframe_pv) 0x10800000)
#define STD_FRAME3  ((gframe_pv) 0x10C00000)
#define STD_FRAME4  ((gframe_pv) 0x11000000) //...advance 0x0040_0000 each
//...NOTE:Frame# (1,2,3,...) can also be used for PF_FRAME & GP_FRAME

#define XMASK   (0x00000FFC)    //10-bits shifted into "x" coordinate
#define YMASK   (0x003FF000)    //10-bits shifted into "y" coordinate
#define FPMASK  (0xFFC00000)    //Upper nibble plus 6-bits for frame#
#define FNMASK  (0x0000003F)    //Just the 6-bits for frame# (before shifting)
#define XSHIFT  (2)
#define YSHIFT  (12)
#define FSHIFT  (22)
#define PIX_PTR(FP,X,Y) ( (pixel_pv) (                    \
    ((uint32_t)(FP)) | ((Y)<<(YSHIFT)) | ((X)<<(XSHIFT)) ) )
#define FRAME_PTR(F)  ( std_frame((uint32_t)(F)) )

//TODO: Make "std_frame" a macro so compiler can compute
inline __attribute__((always_inline))
gframe_pv std_frame(uint32_t const fn_or_fp)
{
    uint32_t fp = (fn_or_fp & (FPMASK));
    if (!fp) fp = (0x10000000 | ((fn_or_fp & (FNMASK)) << (FSHIFT)));
    return (gframe_pv)fp;
}


// *** GP_GCODE COMMANDs: INST Fields, OpCodes, etc. ***

typedef struct __attribute__ ((aligned (4), packed)) cmd_orgb28_s {
    unsigned gop:4;     // High nibble only
    unsigned xrgb28:28; // Foreground/Edge color missing high nibble
} cmd_orgb28_t, *cmd_orgb28_p;
typedef struct __attribute__ ((aligned (4), packed)) cmd_xrgb32_s {
    unsigned xrgb32:32; // Upper "extra" byte as "special purpose"
} cmd_xrgb32_t, *cmd_xrgb32_p;
typedef struct __attribute__ ((aligned (4), packed)) cmd_pnt_s {
    unsigned flags1:6;
    unsigned x:10;
    unsigned flags2:6;
    unsigned y:10;
} cmd_pnt_t, *cmd_pnt_p;
typedef union gpcode_u {
    uint32_t u32;
    cmd_orgb28_t    fORGB28;
    cmd_xrgb32_t    fXRGB32;
    cmd_pnt_t       fPNT;
} gpcode_t, *gpcode_p;

//NOTE: These are 4-bit "nibbles", not actually bytes
#define GOP_STOP    (0)
#define GOP_FILL    (1)
#define GOP_LINE    (2)
#define GOP_ELIP    (3)
#define GOP_RECT    (4)

#define CMD_orgb28(_GOP,_XRGB28) \
            ({const cmd_orgb28_t c={.gop=(_GOP),.xrgb28=(_XRGB28)};             c;})
#define CMD_xrgb32(_XRGB32) \
            ({const cmd_xrgb32_t c={.xrgb32=(_XRGB32)};                         c;})
#define CMD_pnt(_X,_Y) \
            ({const cmd_pnt_t  p={.x=(_X),.y=(_Y),.flags1=0,    .flags2=0    }; p;})
#define CMD_pntflags(_X,_Y,_F1,_F2) \
            ({const cmd_pnt_t  p={.x=(_X),.y=(_Y),.flags1=(_F1),.flags2=(_F2)}; p;})

#define CMD32_orgb28(_GOP,_U28) \
            ((uint32_t)( (( (_GOP) & 0x0F  )<<28) | ((_U28) & 0x0FFFFFFF) ))
#define CMD32_xrgb32(_XRGB32) \
            ((uint32_t)(_XRGB32)                                           )
#define CMD32_pnt(_X,_Y) \
            ((uint32_t)( ((   (_X) & 0x03FF)<<16) | (  (_Y) &     0x03FF) ))
//MISSING: CMD32_pntflags like CMD_pntflags!

#define CMD_STOP()      CMD_orgb28(GOP_STOP,0)    //ZEROS; No trailing words
#define CMD_FILL(_XC28) CMD_orgb28(GOP_FILL,_XC28)  //COLOR; No trailing words
#define CMD_LINE(_XC28) CMD_orgb28(GOP_LINE,_XC28)  //COLOR; 2 x CMD_point (X0,Y0,X1,Y1)
#define CMD_ELIP(_XC28) CMD_orgb28(GOP_ELIP,_XC28)  //COLOR; 2 x CMD_point (XC,YC,A,B) + FILL_COLOR
#define CMD_RECT(_XC28) CMD_orgb28(GOP_RECT,_XC28)  //COLOR; 2 x CMD_point (L,T,R,B)   + FILL_COLOR

gpcode_p hw_OpRGB_PP_S(
    gpcode_p pINST, //NULL uses GPTEMP_PTR & launchs single cmd pronto
    const cmd_orgb28_t  orgb28, //Required: Use cmd_orgb28(op,rgb28)
    const cmd_pnt_t     p0,     //Opt: pnt_null if op doesn't use point
    const cmd_pnt_t     p1,     //Opt: pnt_null if unused
    const cmd_xrgb32_t  xrgb32  //Opt: Full 32-bits (upper byte interpreted elsewhere!)
);
extern const cmd_pnt_t      null_pnt;
extern const cmd_xrgb32_t   null_xrgb32;


//These macros "enqueue" a single operation and trigger immediately:
#define hwfill(_C28)                        \
    hw_OpRGB_PP_S( NULL, CMD_FILL(_C28),     \
        null_pnt, null_pnt,                   \
        null_xrgb32)
#define hwline(_C28,_X0,_Y0,_X1,_Y1)        \
    hw_OpRGB_PP_S( NULL, CMD_LINE(_C28),     \
        CMD_pnt(_X0,_Y0), CMD_pnt(_X1,_Y1),   \
        null_xrgb32)
#define hwelip(_EC28,_XC,_YC,_A,_B,_FC32)   \
    hw_OpRGB_PP_S( NULL, CMD_ELIP(_EC28),    \
        CMD_pnt(_XC,_YC), CMD_pnt(_A,_B),     \
        CMD_xrgb32(_FC32))
#define hwrect(_EC28,_L,_T,_R,_B,_FC32)     \
    hw_OpRGB_PP_S( NULL, CMD_RECT(_EC28),    \
        CMD_pnt(_L,_T), CMD_pnt(_R,_B),       \
        CMD_xrgb32(_FC32))
//A few fake operations/shapes:
#define hwcirc(_EC28,_XC,_YC,_R,_FC32) \
            hwelip((_EC28),(_XC),(_YC),(_R),(_R),(_FC32))
#define hwpixl(_C28,_X,_Y) \
            hwline((_C28), (_X),(_Y), (_X),(_Y))

//These macros enqueue GOPs into a sequence, advancing ptr for each:
#define hwq_stop(_QPTR)                           \
    hw_OpRGB_PP_S( _QPTR, CMD_STOP(),              \
        null_pnt, null_pnt,                         \
        null_xrgb32)
#define hwq_fill(_QPTR,_C28)                      \
    hw_OpRGB_PP_S( _QPTR, CMD_FILL(_C28),          \
        null_pnt, null_pnt,                         \
        null_xrgb32)
#define hwq_line(_QPTR,_C28,_X0,_Y0,_X1,_Y1)      \
    hw_OpRGB_PP_S( _QPTR, CMD_LINE(_C28),          \
        CMD_pnt(_X0,_Y0), CMD_pnt(_X1,_Y1),         \
        null_xrgb32)
#define hwq_elip(_QPTR,_EC28,_XC,_YC,_A,_B,_FC32) \
    hw_OpRGB_PP_S( _QPTR, CMD_ELIP(_EC28),         \
        CMD_pnt(_XC,_YC), CMD_pnt(_A,_B),           \
        CMD_xrgb32(_FC32))
#define hwq_rect(_QPTR,_EC28,_L,_T,_R,_B,_FC32)   \
    hw_OpRGB_PP_S( _QPTR, CMD_RECT(_EC28),         \
        CMD_pnt(_L,_T), CMD_pnt(_R,_B),             \
        CMD_xrgb32(_FC32))
//A few fake operations/shapes:
#define hwq_circ(_QPTR,_EC28,_XC,_YC,_R,_FC32) \
            hwq_elip((_QPTR),(_EC28),(_XC),(_YC),(_R),(_R),(_FC32))
#define hwq_pixl(_QPTR,_C28,_X,_Y) \
            hwq_line((_QPTR),(_C28), (_X),(_Y), (_X),(_Y))


//Software graphics functions
void swslr(gframe_pv frame, color_t color_edge,
              uint16_t Y, uint16_t L,  uint16_t R,
              color_t color_fill);

//inline __attribute__((always_inline))
//void swfill_rect(gframe_pv frame, color_t color);
void swfill_unroll(gframe_pv frame, color_t color);
#define swfill swfill_unroll

void swline(gframe_pv frame, color_t color,
              uint16_t x0, uint16_t y0,
              uint16_t x1, uint16_t y1);
void swelip(gframe_pv frame, color_t color_edge,
              uint16_t xc, uint16_t yc,
              uint16_t a,  uint16_t b,
              color_t color_fill);
void swrect(gframe_pv frame, color_t color_edge,
              uint16_t L, uint16_t T,
              uint16_t R,  uint16_t B,
              color_t color_fill);
/* void swcirc(gframe_pv frame, color_t color_edge,
              uint16_t xc, uint16_t yc,
              uint16_t r); */
/* void swcirc_old(gframe_pv frame, color_t color,
                  uint16_t xc, uint16_t yc,
                  uint16_t r); */
#define swcirc(frame,color_edge,xc,yc,r,color_fill) \
            swelip((frame),(color_edge),(xc),(yc),(r),(r),(color_fill))
#define swpixl(_FRAME, _COLOR32, _X, _Y) \
    { *PIX_PTR(_FRAME, _X, _Y) = _COLOR32; }
/* void swpixl(gframe_pv frame, color_t color,
              uint16_t x,  uint16_t y); */

inline __attribute__((always_inline))
void swslr_4way(
    gframe_pv const fp, color_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy,
    color_t const color_fill)
{
    swslr(fp, color_edge, yc-oy, xc-ox, xc+ox, color_fill);
    swslr(fp, color_edge, yc+oy, xc-ox, xc+ox, color_fill);
}
/* void swpixl_4way(gframe_pv fp, color_t color_edge,
                    uint16_t xc, uint16_t yc,
                    uint16_t ox, uint16_t oy); */
/* void swpixl_8way(gframe_pv fp, color_t color,
                    uint16_t xc, uint16_t yc,
                    uint16_t ox, uint16_t oy); */

#endif
