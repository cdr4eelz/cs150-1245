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
    *PIX_PTR(fp, y, x) = color;
}

//utility methods
void swap(uint16_t* a, uint16_t* b)
{
  uint16_t tmp = *a;
  *a = *b;
  *b = tmp;
}

uint16_t abs(int a) 
{
   if (a < 0) return -a;
   return a;
}

// Based on wikipedia implementation
void swline(const uint32_t color, uint16_t x0, uint16_t y0,
            uint16_t x1, uint16_t y1, const uint32_t frame)
{
    const uint32_t *fp = FRAME_PTR(frame);
    char steep = (abs(y1-y0) > abs(x1-x0)) ? 1 : 0;
    if (steep) {
        swap(&x0, &y0);
        swap(&x1, &y1);
    }
    if (x0 > x1) {
        swap(&x0, &x1);
        swap(&y0, &y1);
    }
    int deltax = x1-x0;
    int deltay = abs(y1-y0);
    int error = deltax / 2;
    int ystep = (y0 < y1) ? 1 : -1;
    int y = y0;
    for (int x = x0; x <= x1; x++) {
        if (steep) {
            SWPIXEL(color, y, x, fp); //One macro style and one...
        } else {
            swpixel(color, x, y, frame); //...function call for testing variety!
        }
        error = error - deltay;
        if (error < 0) {
            y += ystep;
            error += deltax;
        }
    }
}
