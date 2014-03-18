#include "graphics.h"

// *** HARDWARE IMPLEMENTATION (Just single GPCODE commands in GPTEMP_PTR) ***

uint32_t* hw_OpRGB_PP_S(const uint8_t op, const uint32_t color,
                        const uint32_t p0, const uint32_t p1);

void hwfill(const uint32_t color)
{
    hw_OpRGB_PP_S(GOP_FILL, color, 0xFFFFFFFF, 0xFFFFFFFF);
}
void hwline(const uint32_t color,
            const uint16_t x0, const uint16_t y0,
            const uint16_t x1, const uint16_t y1)
{
    hw_OpRGB_PP_S(GOP_LINE, color,
                  CMD_point(x0,y0),
                  CMD_point(x1,y1));
}
void hwpixel(const uint32_t color,
             const uint16_t x, const uint16_t y)
{
    hw_OpRGB_PP_S(GOP_PIXEL, color,
                  CMD_point(x,y), 0xFFFFFFFF);
}
void hwelipse(const uint32_t color,
              const uint16_t xc, const uint16_t yc,
              const uint16_t rx, const uint16_t ry)
{
    hw_OpRGB_PP_S(GOP_ELIPSE, color,
                  CMD_point(xc,yc),
                  CMD_point(rx,ry));
}

uint32_t* hw_OpRGB_PP_S(const uint8_t op, const uint32_t color,
                        const uint32_t p0, const uint32_t p1)
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

void swfill(const gframe_pv fp, const uint32_t color)
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

// Based on wikipedia implementation
void swline(const gframe_pv fp, const uint32_t color,
            const uint16_t x0, const uint16_t y0,
            const uint16_t x1, const uint16_t y1)
{
    const char steep = (ABSDIF(y1,y0) > ABSDIF(x1,x0)) ? 1 : 0;
    uint16_t a0, a1, b0, b1, tmp;
    if (steep) {
        a0 = y0; b0 = x0; //swap_u16(&x0, &y0);
        a1 = y1; b1 = x1; //swap_u16(&x1, &y1);
    } else {
        a0 = x0; b0 = y0;
        a1 = x1; b1 = y1;
    }
    if (a0 > a1) {
        SWAP(a0,a1,tmp); //swap_u16(&a0, &a1);
        SWAP(b0,b1,tmp); //swap_u16(&b0, &b1);
    }
    const uint32_t yOff = (b0 < b1) ? 1 : -1;
    const uint32_t deltay = ABSDIF(b1,b0); //Always subtracted from error
    const uint32_t deltax = (a1 - a0); //Guaranteed >= 0

    int32_t error = (int32_t)(deltax >> 1); //(deltax>>1)==(deltax/2)
    uint16_t x = a0, y = b0;
    while (x <= a1) {
        if (steep) {
            swpixel(fp,color, y,x);
//          *PIX_PTR(fp, y,x) = color;
        } else {
//          swpixel(fp,color, x,y);
            *PIX_PTR(fp, x,y) = color;
        }
        error -= deltay;
        if (error < 0) {
            y += yOff;
            error += deltax;
        }
        x++;
    }
}

void swpixel(const gframe_pv fp, const uint32_t color,
             const uint16_t x, const uint16_t y)
{
    *PIX_PTR(fp, x, y) = color;
}

void swcircle(const gframe_pv fp, const uint32_t color,
              const uint16_t xc, const uint16_t yc,
              const uint16_t r)
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

void swelipse(const gframe_pv fp, const uint32_t color,
              const uint16_t xc, const uint16_t yc,
              const uint16_t rx, const uint16_t ry)
{
//TODO:Optimize SQUARE(uint16_t):uint32_t
    uint16_t x = 0, y = ry; //theta=0; fake "origin" (translate pixels later)
    const uint32_t a2p = (rx^2)<<1; //scale2x: rx^2
    const uint32_t b2p = (ry^2)<<1; //scale2x: ry^2
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

void swcircle_old(const gframe_pv fp, const uint32_t color,
                  const uint16_t xc, const uint16_t yc,
                  const uint16_t r)
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


void swpixel_4way(const gframe_pv fp, const uint32_t color,
                  const uint16_t xc, const uint16_t yc,
                  const int16_t ox,  const int16_t oy)
{
//TODO:Avoid recompute of pixel address
    *PIX_PTR(fp, xc - ox, yc - oy) = color;
    *PIX_PTR(fp, xc + ox, yc - oy) = color;
    *PIX_PTR(fp, xc - ox, yc + oy) = color;
    *PIX_PTR(fp, xc + ox, yc + oy) = color;
}

void swpixel_8way(const gframe_pv fp, const uint32_t color,
                  const uint16_t xc, const uint16_t yc,
                  const int16_t ox,  const int16_t oy)
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
