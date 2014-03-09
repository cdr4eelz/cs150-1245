#include "graphics.h"

void hwfill(const uint32_t color, const uint32_t frame)
{
  //TODO: write this function and modify the interface to how your design handles this
}

void hwline(const uint32_t color, const uint16_t x0, const uint16_t y0,
            const uint16_t x1, const uint16_t y1, const uint32_t frame)
{
  //TODO: write this function and modify the interface to how your design handles this
}

void hwpixel(const uint32_t color, const uint16_t x, const uint16_t y,
             const uint32_t frame)
{
  //TODO: write this function and modify the interface to how your design handles this
}

void swfill(const uint32_t color, const uint32_t frame)
{
    uint32_t *pPIX = FRAME_PTR(frame); //Pointer to frame base address
    for (int nROW = 0; nROW < ROW_SIZEP; nROW++) {
        for (int nCOL = 0; nCOL < COL_SIZEP; nCOL++) {
            *pPIX++ = color; //Advance 4bytes each time
        }
        pPIX += (ROW_OFFSETP - COL_SIZEP); //Advance what we have yet to apply of the offset
    }
}

void swpixel(uint32_t color, const uint16_t x, const uint16_t y,
             const uint32_t frame)
{
    const uint32_t *fp = FRAME_PTR(frame);
    *PIX_PTR(x, y, fp) = color;
}


// Based on wikipedia implementation
void swline(const uint32_t color, const uint16_t x0, const uint16_t y0,
            const uint16_t x1, const uint16_t y1, const uint32_t frame)
{
    uint16_t a0, a1, b0, b1, tmp;
    const uint32_t *fp = FRAME_PTR(frame);
    char steep = (ABSDIF(y1,y0) > ABSDIF(x1,x0)) ? 1 : 0;
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
    char yinc = (b0 < b1) ? 1 : -1;
    int32_t deltax = (a1 - a0); //Guaranteed >= 0
    int32_t deltay = ABSDIF(b1,b0);
    int32_t error = (int)deltax / 2;
    uint16_t y = b0;
    for (uint16_t x = a0; x <= a1; x++) {
        if (steep) {
            *PIX_PTR(y, x, fp) = color; //swpixel(color, y, x, fp);
        } else {
            swpixel(color, x, y, frame);
//          *PIX_PTR(x, y, fp) = color;
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
