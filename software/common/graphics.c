#include "graphics.h"

// *** UTILITY ROUTINES ***

gframe_pv std_frame(uint32_t const fn_or_fp) {
    uint32_t fp = (fn_or_fp & (FPMASK));
    if (!fp) fp = (0x10000000 | ((fn_or_fp & (FNMASK)) << (FSHIFT)));
    return (gframe_pv)fp;
}



// *** HARDWARE IMPLEMENTATION (Just single GPCODE command in GPTEMP_PTR) ***

uint32_t* hw_OpRGB_PP_S(uint8_t const op, uint32_t const color,
                        uint32_t const p0, uint32_t const p1);

void hwfill(uint32_t const color)
{
    hw_OpRGB_PP_S(GOP_FILL, color, 0xFFFFFFFF, 0xFFFFFFFF);
}
void hwline(uint32_t const color,
            uint16_t const x0, uint16_t const y0,
            uint16_t const x1, uint16_t const y1)
{
    hw_OpRGB_PP_S(GOP_LINE, color,
                  CMD_point(x0,y0),
                  CMD_point(x1,y1));
}
void hwpixel(uint32_t const color,
             uint16_t const x, uint16_t const y)
{
    hw_OpRGB_PP_S(GOP_PIXEL, color,
                  CMD_point(x,y), 0xFFFFFFFF);
}
void hwelipse(uint32_t const color,
              uint16_t const xc, uint16_t const yc,
              uint16_t const rx, uint16_t const ry)
{
    hw_OpRGB_PP_S(GOP_ELIPSE, color,
                  CMD_point(xc,yc),
                  CMD_point(rx,ry));
}

uint32_t* hw_OpRGB_PP_S(uint8_t const op, uint32_t const color,
                        uint32_t const p0, uint32_t const p1)
{
    uint32_t* pINST = GPTEMP_PTR;
    *pINST++ = CMD_rgb(op, color);
    if (p0 != 0xFFFFFFFF) *pINST++ = p0;
    if (p1 != 0xFFFFFFFF) *pINST++ = p1;
    *pINST++ = CMD_STOP();
    GP_GCODE = GPTEMP_PTR;
    return pINST;
}



// *** SOFTWARE IMPLEMENTATIONS ***

void swfill(gframe_pv const fp, uint32_t const color)
{
    pixel_pv pPIX = (pixel_pv)fp; //Start at pointer to frame base address
    for (int nROW = 0; nROW < ROW_SIZEP; nROW++) {
        for (int nCOL = 0; nCOL < COL_SIZEP; nCOL+=8) {
            *pPIX++ = color; //Advance 1-word (4-bytes) each time
            *pPIX++ = color; //  "unrolled" to 8 pixels
            *pPIX++ = color; //  or 8 x 32-bit words
            *pPIX++ = color; //  or 2 x 128-bit DDR-halves
            *pPIX++ = color; //  or 1 x 256-bit DDR "lane"
            *pPIX++ = color; //  which matches cacheline
            *pPIX++ = color; //  though these stores have no
            *pPIX++ = color; //  direct correlation with that!
        }
        //Advance from 1-past last-row-pixel to start-pixel of next-row
        pPIX += (ROW_OFFSETP - COL_SIZEP); //Remainder of row-offset not applied above
    }
}

// UNSIGNED only, isolated PREP/ITER stages, identified PARALLEL blocks
void swline(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    int16_t const difXs = (x1 - x0);
    int16_t const difYs = (y1 - y0);
    BOOL const decrX = (difXs < 0), decrY = (difYs < 0);
    uint16_t const difXu = (decrX) ? -difXs : difXs;
    uint16_t const difYu = (decrY) ? -difYs : difYs;
    BOOL const spin = (difYu > difXu) ? 1 : 0;
    BOOL const flip = (spin) ? decrY : decrX;
    uint16_t a0, a1, b0, b1;
    if (spin) {
        if (flip) {
            a0 = y1; b0 = x1; //swap_u16(&x0, &y0) & swap_u16(&a0, &a1);
            a1 = y0; b1 = x0; //swap_u16(&x1, &y1) & swap_u16(&b0, &b1);
        } else {
            a0 = y0; b0 = x0; //swap_u16(&x0, &y0);
            a1 = y1; b1 = x1; //swap_u16(&x1, &y1);
        }
    } else {
        if (flip) {
            a0 = x1; b0 = y1; //swap_u16(&a0, &a1);
            a1 = x0; b1 = y0; //swap_u16(&b0, &b1);
        } else {
            a0 = x0; b0 = y0;
            a1 = x1; b1 = y1;
        }
    }
    BOOL const incB = (b1 > b0);
    uint32_t const offB = (incB) ? 1 : 0xFFFFFFFF; //B addend fake-signed (+/- 1)
    //uint32_t const errB = (incB) ? (b1 - b0) : (b0 - b1); //Error subtracted portion (arrange >= 0)
    //negB = (~errB + 1);
    uint32_t const negB = (incB) ? (b0 - b1) : (b1 - b0); //Error addend fake-signed (arrange "<=" 0)
    uint32_t const errA = (a1 - a0); //Error addend; (guaranteed >= 0)
    uint32_t const posA = (errA + negB); //Error addend signed, net after errA/2 (guaranteed >= 0)
    uint32_t error = (errA >> 1); //error is s30.1 fixed-point signed (guaranteed >= 0)
    uint16_t a = a0, b = b0;
    while (a <= a1) {
        //FORK:iter-1
        uint32_t const nextA = a + 1;
        uint32_t const nextB = b + offB;
        uint32_t const errorA = error + posA;
        uint32_t const errorB = error + negB;
        uint16_t x = ((spin) ? b : a);
        uint16_t y = ((spin) ? a : b);
        swpixel(fp,color, x,y);
        //JOIN:iter-1
        //FORK:iter-2
        a     = nextA;
        b     = (errorB & 0x80000000) ? nextB  : b;
        error = (errorB & 0x80000000) ? errorA : errorB;
        //JOIN:iter-2
    }
}

void swpixel(gframe_pv const fp, uint32_t const color,
             uint16_t const x, uint16_t const y)
{
    *PIX_PTR(fp, x, y) = color;
//  printf("%4d %4d\n", x,y);
}

void swcircle(gframe_pv const fp, uint32_t const color,
              uint16_t const xc, uint16_t const yc,
              uint16_t const r)
{
    int32_t x, y, d, dE, dSE;
    x = 0; //theta=0; fake "origin" (translate pixels later)
    y = r; //theta=0
    d   = 1 - r;          //scale2x: 0.5*(1-r)
    dE  = 2 + 1;          //scale2x: 1.5
    dSE = (-2*r) + 4 + 1; //scale2x: -r + 2.5
    swpixel_8way(fp,color, xc,yc, x,y);
    while (y > x) {
        if (d < 0) {
            d += dE;
            dE += 2;
            dSE += 2;
            ++x;
        } else {
            d += dSE;
            dE += 2;
            dSE += 4;
            ++x;
            --y;
        }
        swpixel_8way(fp,color, xc,yc, x,y);
    }
}

void swelipse(gframe_pv const fp, uint32_t const color,
              uint16_t const xc, uint16_t const yc,
              uint16_t const rx, uint16_t const ry)
{
//TODO:Optimize SQUARE(uint16_t):uint32_t
    uint16_t x = 0, y = ry; //theta=0; fake "origin" (translate pixels later)
    uint32_t const a2p = (rx^2)<<1; //scale2x: rx^2
    uint32_t const b2p = (ry^2)<<1; //scale2x: ry^2
    int32_t dd; //dd

//TODO:Pre-compute dd increments
//  dd = b2p - (a2p * (y   )) + (a2p /4);
    dd = b2p - (a2p * (y<<1)) + (a2p>>2); //scale2x:
    swpixel_4way(fp,color, xc,yc, x,y);
//  while ((a2p*((y   )-(0.5))) > (b2p*((x   )+(1.0)))) {
    while ((a2p*((y<<1)-(  1))) > (b2p*((x<<1)+(  2)))) {
        if (dd < 0) {
//          dd += (b2p * ((x *2) + 3));
            dd += (b2p * ((x<<2) + 6)); //scale2x:
        } else {
//          dd += (b2p * ((x *2) + 3)) + (a2p * (-(y *2) + 2));
            dd += (b2p * ((x<<2) + 6)) + (a2p * (-(y<<2) + 4)); //scale2x:
            --y;
        }
        ++x;
        swpixel_4way(fp,color, xc,yc, x,y);
    }

    //Transition at slope=1, whatever theta happens to be; Reverse x&y roles
//  dd = (a2p*(((   y)-(1.0))^2)) + (b2p*(((x   )+0.5)^2)) - (a2p*b2p);
    dd = (a2p*(((y<<1)-(  2))^2)) + (b2p*(((x<<1)+  1)^2)) - (a2p*b2p);
    while (y > 0) {
        if (dd < 0) {
//          dd += (a2p * (-(y *2) + 3)) + (b2p * ((x *2) + 2));
            dd += (a2p * (-(y<<2) + 6)) + (b2p * ((x<<2) + 4)); //scale2x:
            ++x;
        } else {
//          dd += (a2p * (-(y *2) + 3)); //scale2x:
            dd += (a2p * (-(y<<2) + 6)); //scale2x:
        }
        --y;
        swpixel_4way(fp,color, xc,yc, x,y);
    }
}

void swcircle_old(gframe_pv const fp, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  uint16_t const r)
{
    int32_t x, y, d;
    x = 0;
    y = r;
    d = 1 - r;
    swpixel_8way(fp,color, xc,yc, x,y);
    while(y > x) {
        if(d < 0) {
            d += ((x<<1) + 3); //(x<<1)==(2*x)
            ++x;
        } else {
            d += (((x-y)<<1) + 5); //(x<<1)==(2*(x-y))
            ++x;
            --y;
        }
        swpixel_8way(fp,color, xc,yc, x,y);
    }
}


void swpixel_4way(gframe_pv const fp, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  int16_t const ox,  int16_t const oy)
{
//TODO:Avoid recompute of pixel address
    *PIX_PTR(fp, xc - ox, yc - oy) = color;
    *PIX_PTR(fp, xc + ox, yc - oy) = color;
    *PIX_PTR(fp, xc - ox, yc + oy) = color;
    *PIX_PTR(fp, xc + ox, yc + oy) = color;
}

void swpixel_8way(gframe_pv const fp, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  int16_t const ox,  int16_t const oy)
{
//TODO:Avoid recompute of pixel address
//    uint16_t o2x = (ox << 1);
//    int16_t xMo = ((int16_t)xc) - ox;
//    pPIX = PIX_PTR(fp, xMo, yc - oy);
//    *pPIX = color;
//    pPIX += o2x;    *pPIX = color;
//    pPIX += (o2y * RADV) - ;    *pPIX = color;
    *PIX_PTR(fp, xc - ox, yc - oy) = color;
    *PIX_PTR(fp, xc + ox, yc - oy) = color;
    *PIX_PTR(fp, xc - ox, yc + oy) = color;
    *PIX_PTR(fp, xc + ox, yc + oy) = color;
    if (ox != oy) { //If always (x==y), call swpixel_4way!
        *PIX_PTR(fp, xc - oy, yc - ox) = color;
        *PIX_PTR(fp, xc + oy, yc - ox) = color;
        *PIX_PTR(fp, xc - oy, yc + ox) = color;
        *PIX_PTR(fp, xc + oy, yc + ox) = color;
    }
}
