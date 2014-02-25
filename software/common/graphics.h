#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"

#define GP_CONTROL  (*((volatile uint32_t*) 0x80000050))
//CONTROL: 
#define GP_CODE     (*((volatile uint32_t*) 0x80000054))
#define GP_FRAME    (*((volatile uint32_t*) 0x80000058))
#define PF_FRAME    (*((volatile uint32_t*) 0x8000005C))

#define STD_FRAME0  (*((volatile uint32_t*) 0x10000000))
#define STD_FRAME1  (*((volatile uint32_t*) 0x10400000))
#define STD_FRAME2  (*((volatile uint32_t*) 0x10800000))
#define STD_FRAME3  (*((volatile uint32_t*) 0x10C00000))

//TODO: modify these declarations as you need them
void hwfill(uint32_t color);
void hwline(uint32_t color, uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1);
void swline(uint32_t color, int x0, int y0, int x1, int y1);
void swfill(uint32_t color);

#endif
