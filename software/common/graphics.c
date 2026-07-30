#include "graphics.h"

#include "mutmath.h"

// *** UTILITY ROUTINES ***



// *** HARDWARE IMPLEMENTATION (Just single GPCODE command in GPTEMP_PTR) ***

gpcode_p hw_OpRGB_PP_S(gpcode_p bINST,
    const struct cmd_rgb const cmd,
    const struct cmd_pnt const p0,
    const struct cmd_pnt const p1)
{
    gpcode_p pINST = (bINST) ? bINST : GPTEMP_PTR;
    GP_WAIT();
    (*pINST++).fRGB = cmd;
    if (p0.flags != pnt_null.flags) (*pINST++).fPNT = p0;
    if (p1.flags != pnt_null.flags) (*pINST++).fPNT = p1;
    if (!bINST) {
        (*pINST++).fRGB = CMD_STOP();
    	GP_GCODE = GPTEMP_PTR;
    }
    return pINST;
}

const struct cmd_pnt pnt_null = { .flags=0x3F };

// *** SOFTWARE IMPLEMENTATIONS ***

void swfill(
    gframe_pv const fp, uint32_t const color)
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
    char const decrX = (difXs < 0), decrY = (difYs < 0);
    uint16_t const difXu = (decrX) ? -difXs : difXs;
    uint16_t const difYu = (decrY) ? -difYs : difYs;
    char const spin = (difYu > difXu);
    char const flip = (spin) ? decrY : decrX;
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
    char const incB = (b1 > b0);
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
        swpixl(fp,color, x,y);
        //JOIN:iter-1
        //FORK:iter-2
        a     = nextA;
        b     = (errorB & 0x80000000) ? nextB  : b;
        error = (errorB & 0x80000000) ? errorA : errorB;
        //JOIN:iter-2
    }
}

void swpixl(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x, uint16_t const y)
{
    *PIX_PTR(fp, x, y) = color;
//  printf("%4d %4d\n", x,y);
}

void swcirc(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const r)
{
    int32_t d, dE, dSE;
    uint16_t x=0, y=r; //theta=90 @"origin" (translate pixels later)

    d   = 1 - r;            //scale2x: 0.5*(1-r)
    dE  = 2 + 1;            //scale2x: 1.5
    dSE = -(r<<1) + 4 + 1;  //scale2x: -r + 2.5
    swpixl_8way(fp,color, xc,yc, x,y);
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
        swpixl_8way(fp,color, xc,yc, x,y);
    }
}

void swelip(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const a, uint16_t const b)
{
    uint16_t x = 0, y = b; //theta=90 @origin (offset pixels in 4way)
    uint32_t const AA = sqr32(a), BB = sqr32(b);
    uint32_t const AABB = mul32(AA,BB);

    //Helper values to pre-compute multiplied values then adjust with addition
    uint32_t AAy    = mul32(AA,y);
    uint32_t BBx    = 0; //(x==0): mul32(BB,x);
    uint32_t BB2xp3 = /*(mul32(BB,x)<<1) +*/ (BB<<1) + BB; //(x==0)
    //uint32_t AA2y   = (AAy<<1); //(mul32(AA,y)<<1);

    int32_t stopper = (AA>>1)+BB;
    int32_t dd      = BB - AAy + (AA>>2); //AAy==mul32(AA,b) since y==b

    swpixl_4way(fp,color, xc,yc, x,y);
    while (((AAy-BBx) > stopper) && (y > 0) && (x <= a)) { // (AAy-(AA>>1)) > (BBx+BB)
        if (dd >= 0) {
            dd += (AA<<1) - (AAy<<1); //mul32(AA,y<<1);
            y--; AAy -= AA; //AA2y -= (AA<<1);
        }
        dd += BB2xp3; //mul32(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
//return;
//printf("\\\\\\\n");
    //Transition at slope=1, whatever theta happens to be; Reverse x&y roles
    uint32_t BB2xp2 = BB2xp3 - BB; //mul32(BB,(x<<1)+2);
    dd = mul32(BB,sqr32(x)+x)+(BB>>2) + mul32(AA,sqr32(y-1)) - AABB;
    while (y > 0) {
        if (dd < 0) {
            dd += BB2xp2; //mul32(BB,(x<<1)+2);
            x++; BB2xp2 += (BB<<1);
        }
        dd += (AA<<1)+AA - (AAy<<1); //mul32(AA,y<<1);
        y--; AAy -= AA; //AA2y -= (AA<<1);
        swpixl_4way(fp,color, xc,yc, x,y);
    }
}


void swcirc_old(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const r)
{
    int32_t d = 1-r;
    uint16_t x = 0, y = r;

    swpixl_8way(fp,color, xc,yc, x,y);
    while(y > x) {
        if(d < 0) {
            d += ((x<<1) + 3); //(x<<1)==(2*x)
            ++x;
        } else {
            d += (((x-y)<<1) + 5); //(x<<1)==(2*(x-y))
            ++x;
            --y;
        }
        swpixl_8way(fp,color, xc,yc, x,y);
    }
}


void swpixl_4way(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy)
{
//TODO:Avoid recompute of pixel address
    *PIX_PTR(fp, xc - ox, yc - oy) = color;
    *PIX_PTR(fp, xc + ox, yc - oy) = color;
    *PIX_PTR(fp, xc - ox, yc + oy) = color;
    *PIX_PTR(fp, xc + ox, yc + oy) = color;
}

void swpixl_8way(
    gframe_pv const fp, uint32_t const color,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy)
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
    if (ox != oy) { //If always (x==y), call swpixl_4way!
        *PIX_PTR(fp, xc - oy, yc - ox) = color;
        *PIX_PTR(fp, xc + oy, yc - ox) = color;
        *PIX_PTR(fp, xc - oy, yc + ox) = color;
        *PIX_PTR(fp, xc + oy, yc + ox) = color;
    }
}
