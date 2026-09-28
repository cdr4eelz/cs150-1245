#include "graphics.h"

#include "mutmath.h"

// *** HARDWARE IMPLEMENTATION ***

// If bINST is NULL, put a single operation in GPTEMP_PTR and trigger:
gpcode_p hw_OpRGB_PP_S(
    gpcode_p bINST,
    const cmd_orgb28_t  const orgb28,
    const cmd_pnt_t     const p0,
    const cmd_pnt_t     const p1,
    const cmd_xrgb32_t  const xrgb32
) {
    gpcode_p pINST = (bINST) ? bINST : GPTEMP_PTR;
    GP_WAIT();
    (*pINST++).fORGB28 = orgb28;
    if (p0.flags1 != null_pnt.flags1) {
        (*pINST++).fPNT = p0;
    }
    if (p1.flags1 != null_pnt.flags1) {
        (*pINST++).fPNT = p1;
    }
    if (xrgb32.xrgb32 != null_xrgb32.xrgb32) {
        (*pINST++).fXRGB32 = xrgb32;
    }
    if (!bINST) {
        (*pINST++).fORGB28 = CMD_STOP();
    	GP_GCODE = GPTEMP_PTR;
    }
    return pINST;
}

// Hacky way to handle "nulls" but quick & easy:
const cmd_pnt_t     null_pnt    = { .flags1 = 0x3F       };
const cmd_xrgb32_t  null_xrgb32 = { .xrgb32 = 0xF101234A };


// *** SOFTWARE IMPLEMENTATION ***

void swslr(gframe_pv frame, color_t color_edge,
              uint16_t Y, uint16_t L,  uint16_t R,
              color_t color_fill)
{
    //TODO: Maybe the two "ifs" can be avoided in the main loop?
    for (uint16_t X = L; X <= R; X++) {
        color_t color = ((X==L) || (X==R)) ? (0xFF000000|color_edge) : color_fill;
        if (color & 0xFF000000) swpixl(frame, color, X, Y);
    }
}

/*
void swfill_rect(
    gframe_pv const fp, uint32_t const color)
{
    swrect(fp, color, 0,0, COL_SIZEP,ROW_SIZEP, color);
}
*/

void swfill_unroll(
    gframe_pv const frame, uint32_t const color)
{
    pixel_pv pPIX = (pixel_pv)frame; //Start at pointer to frame base address
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

void swrect(gframe_pv const frame, color_t const color_edge,
              uint16_t L, uint16_t T,
              uint16_t R,  uint16_t B,
              color_t const color_fill)
{
    uint16_t temp;
    if (R < L) {temp=L;L=R;R=temp;};
    if (B < T) {temp=T;T=B;B=temp;};
    for (int Y = T; Y <= B; Y++) {
//TODO: Maybe the conditional can be avoided in main loop?
        color_t color = ((Y==T) || (Y==B)) ? (0xFF000000|color_edge) : color_fill;
        swslr(frame, color_edge, Y, L, R, color);
    }
}

// UNSIGNED only, isolated PREP/ITER stages, identified PARALLEL blocks
//TODO: Combine "run" of pixels on same "y" into SLR call
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

/*
void swpixl(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x, uint16_t const y)
{
    *PIX_PTR(fp, x, y) = color;
//  printf("%4d %4d\n", x,y);
}
*/

/*
void swcirc(
    gframe_pv const fp, uint32_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const r) //TODO: fill_color and SLR
{
    int32_t d, dE, dSE;
    uint16_t x=0, y=r; //theta=90 @"origin" (translate pixels later)

    d   = 1 - r;            //scale2x: 0.5*(1-r)
    dE  = 2 + 1;            //scale2x: 1.5
    dSE = -(r<<1) + 4 + 1;  //scale2x: -r + 2.5
    swpixl_8way(fp,color_edge, xc,yc, x,y);
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
        swpixl_8way(fp,color_edge, xc,yc, x,y);
    }
}
*/

//TODO: Use "edge" color for top & bottom "y" extremes.
//TODO: Combine "runs" of pixels on same "y" into single SLR call.
void swelip(
    gframe_pv const fp, color_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const a, uint16_t const b,
    color_t const color_fill)
{
    uint16_t x = 0, y = b; //theta=90 @origin (offset pixels in 4way)
    uint32_t const AA = sqr32u(a), BB = sqr32u(b); // 16u in, 32u out
    uint32_t const AABB = mul32u(AA,BB);

    //Helper values to pre-compute multiplied values then adjust with addition
    uint32_t AAy    = mul32u(AA,y); //NOTE: INITIALLY AAy == AAb (since y==b INITIALLY)
    uint32_t BBx    = 0; //(x==0): mul32u(BB,x);
    uint32_t BB2xp3 = /*(mul32u(BB,x)<<1) +*/ (BB<<1) + BB; //(x==0)
    //uint32_t AA2y   = (AAy<<1); //(mul32u(AA,y)<<1);

    // NOTE: "dd" and "stopper" are signed, unlike other vars
    int32_t stopper = (AA>>1)+BB; // Always positive but signed to help compare below
    int32_t dd      = BB - AAy + (AA>>2); //AAy==mul32u(AA,b) since y==b

    //TODO: Need to manage signed/unsigned value comparisons better (more explicitly)
    //swpixl_4way(fp,color_edge, xc,yc, x,y);
    swslr_4way(fp,color_edge, xc,yc, x,y, color_fill);
    while (((AAy-BBx) > stopper) && (y > 0) && (x <= a)) { // (AAy-(AA>>1)) > (BBx+BB)
        if (dd >= 0) {
            dd += (AA<<1) - (AAy<<1); //mul32u(AA,y<<1);
            y--; AAy -= AA; //AA2y -= (AA<<1);
        }
        dd += BB2xp3; //mul32u(BB,(x<<1)+3);
        x++; BBx += BB; BB2xp3 += (BB<<1);
        //swpixl_4way(fp,color_edge, xc,yc, x,y);
        swslr_4way(fp,color_edge, xc,yc, x,y, color_fill);
    }
//return;
//printf("\\\\\\\n");
    //Transition at slope=1, whatever theta happens to be; Reverse x&y roles
    uint32_t BB2xp2 = BB2xp3 - BB; //mul32u(BB,(x<<1)+2);
    dd = mul32u(BB,sqr32u(x)+x)+(BB>>2) + mul32u(AA,sqr32u(y-1)) - AABB;
    while ((y > 0) && (x <= a)) {
        if (dd < 0) {
            dd += BB2xp2; //mul32u(BB,(x<<1)+2);
            x++; BB2xp2 += (BB<<1);
        }
        dd += (AA<<1)+AA - (AAy<<1); //mul32u(AA,y<<1);
        y--; AAy -= AA; //AA2y -= (AA<<1);
        //swpixl_4way(fp,color_edge, xc,yc, x,y);
        swslr_4way(fp,color_edge, xc,yc, x,y, color_fill);
    }
}

/*
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
*/

/*
void swpixl_4way(
    gframe_pv const fp, color_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy,
    color_t const color_fill)
{
//TODO:Avoid recompute of pixel address
    *PIX_PTR(fp, xc - ox, yc - oy) = color_edge;
    *PIX_PTR(fp, xc + ox, yc - oy) = color_edge;
    *PIX_PTR(fp, xc - ox, yc + oy) = color_edge;
    *PIX_PTR(fp, xc + ox, yc + oy) = color_edge;
}
*/

/*
void swslr_4way(
    gframe_pv const fp, color_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy,
    color_t const color_fill)
{
    swslr(fp, color_edge, yc-oy, xc-ox, xc+ox, color_fill);
    swslr(fp, color_edge, yc+oy, xc-ox, xc+ox, color_fill);
}
*/

/*
void swpixl_8way(
    gframe_pv const fp, uint32_t const color_edge,
    uint16_t const xc, uint16_t const yc,
    uint16_t const ox, uint16_t const oy) //TODO: color_fill and/or SLR
{
//TODO:Avoid recompute of pixel address
//    uint16_t o2x = (ox << 1);
//    int16_t xMo = ((int16_t)xc) - ox;
//    pPIX = PIX_PTR(fp, xMo, yc - oy);
//    *pPIX = color_edge;
//    pPIX += o2x;    *pPIX = color_edge;
//    pPIX += (o2y * RADV) - ;    *pPIX = color_edge;
    *PIX_PTR(fp, xc - ox, yc - oy) = color_edge;
    *PIX_PTR(fp, xc + ox, yc - oy) = color_edge;
    *PIX_PTR(fp, xc - ox, yc + oy) = color_edge;
    *PIX_PTR(fp, xc + ox, yc + oy) = color_edge;
    if (ox != oy) { //If always (x==y), call swpixl_4way!
        *PIX_PTR(fp, xc - oy, yc - ox) = color_edge;
        *PIX_PTR(fp, xc + oy, yc - ox) = color_edge;
        *PIX_PTR(fp, xc - oy, yc + ox) = color_edge;
        *PIX_PTR(fp, xc + oy, yc + ox) = color_edge;
    }
}
*/
