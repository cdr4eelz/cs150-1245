#include "graphics.h"

// *** HARDWARE IMPLEMENTATION (Just single GPCODE commands in GPTEMP_PTR) ***

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
    GP_CODE = *GPTEMP_PTR;
    return pINST;
}



// *** SOFTWARE IMPLEMENTATIONS ***

void swfill(uint32_t const frame, uint32_t const color)
{
    uint32_t *pPIX = FRAME_PTR(frame); //Start at pointer to frame base address
    for (int nROW = 0; nROW < ROW_SIZEP; nROW++) {
        for (int nCOL = 0; nCOL < COL_SIZEP; nCOL++) {
            *pPIX++ = color; //Advance 1-word (4-bytes) each time
        }
        pPIX += (ROW_OFFSETP - COL_SIZEP); //Advance what we have yet to apply of the offset
    }
}

// Based on wikipedia implementation
void swline(uint32_t const frame, uint32_t const color,
            uint16_t const x0, uint16_t const y0,
            uint16_t const x1, uint16_t const y1)
{
    uint32_t* const fp = FRAME_PTR(frame);
    char const steep = (ABSDIF(y1,y0) > ABSDIF(x1,x0)) ? 1 : 0;
    uint16_t a0, a1, b0, b1, tmp;
    if (steep) {
        a0 = y0; a1 = y1; //swap_u16(&x0, &y0);
        b0 = x0; b1 = x1; //swap_u16(&x1, &y1);
    } else {
        a0 = x0; a1 = x1;
        b0 = y0; b1 = y1;
    }
    if (a0 > a1) {
        SWAP(a0,a1,tmp); //swap_u16(&a0, &a1);
        SWAP(b0,b1,tmp); //swap_u16(&b0, &b1);
    }
    char const yinc = (b0 < b1) ? 1 : -1;
    int32_t const deltax = (a1 - a0); //Guaranteed >= 0
    int32_t const deltay = ABSDIF(b1,b0);

    int32_t error = (int32_t)(deltax / 2);
    uint16_t y = b0;
    for (uint16_t x = a0; x <= a1; x++) {
        if (steep) {
            swpixel(frame,color, y,x);
//          *PIX_PTR(fp, y,x) = color;
        } else {
//          swpixel(frame,color, x,y);
            *PIX_PTR(fp, x,y) = color;
        }
        error = error - deltay;
        if (error < 0) {
            if (yinc) {
                y += 1;
            } else {
                y -= 1;
            }
            error += deltax;
        }
    }
}

void swpixel(uint32_t const frame, uint32_t const color,
             uint16_t const x, uint16_t const y)
{
    uint32_t* const fp = FRAME_PTR(frame);
    *PIX_PTR(fp, x, y) = color;
}

void swcircle_old(uint32_t const frame, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  uint16_t const r)
{
    uint32_t* const fp = FRAME_PTR(frame);
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

void swcircle(uint32_t const frame, uint32_t const color,
              uint16_t const xc, uint16_t const yc,
              uint16_t const r)
{
    uint32_t* const fp = FRAME_PTR(frame);
    int32_t x, y, d, dE, dSE;
    x = 0;
    y = r;
    d = 1 - r;
    dE = 3;
    dSE = (-2*r) + 5;
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

void swelipse(uint32_t const frame, uint32_t const color,
              uint16_t const xc, uint16_t const yc,
              uint16_t const rx, uint16_t const ry)
{
    uint32_t* const fp = FRAME_PTR(frame);
    int32_t const a2p = (rx^2);
    int32_t const b2p = (ry^2);
    int32_t x, y, d1, d2;
    x = 0;
    y = ry;
    d1 = b2p - (a2p * ry) + (a2p / 4);
    swpixel_4way(fp,color, xc,yc, x,y);
//  while ((a2p * (y-(0.5))) > (b2p * (x+1))){
    while ((a2p * (y-(1))) > (b2p * (x+1))) {
        if (d1<0) {
            d1 += (b2p * (2*x + 3));
            ++x;
        } else {
            d1 += (b2p * (2*x + 3)) + (a2p * (-2*y + 2));
            ++x;
            --y;
        }
        swpixel_4way(fp,color, xc,yc, x,y);
    }
//  d2 = (b2p * ((x+0.5)^2)) + (a2p * ((y-1)^2)) - (a2p * b2p);
    d2 = (b2p * ((x+1)^2)) + (a2p * ((y-1)^2)) - (a2p * b2p);
    while (y>0) {
        if (d2<0) {
            d2 += (b2p * (2*x + 2)) + (a2p * (-2*y + 3));
            ++x;
            --y;
        } else {
            d2 += (a2p * (-2*y + 3));
            --y;
        }
        swpixel_4way(fp,color, xc,yc, x,y);
    }
}


void swpixel_4way(uint32_t* const fp, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  int16_t const ox,  int16_t const oy)
{
    *PIX_PTR(fp, xc - ox, yc - oy) = color;
    *PIX_PTR(fp, xc + ox, yc - oy) = color;
    *PIX_PTR(fp, xc - ox, yc + oy) = color;
    *PIX_PTR(fp, xc + ox, yc + oy) = color;
}

void swpixel_8way(uint32_t* const fp, uint32_t const color,
                  uint16_t const xc, uint16_t const yc,
                  int16_t const ox,  int16_t const oy)
{
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
