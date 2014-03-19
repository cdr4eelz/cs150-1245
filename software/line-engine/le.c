#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef int   int32_t;
typedef short int16_t;
//typedef char  int8_t;
typedef unsigned int   uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char  uint8_t;
#define BOOL _Bool

typedef uint32_t gframe_pv;


typedef void (*line_FUNC)(gframe_pv, uint32_t,
                          uint16_t, uint16_t,
                          uint16_t, uint16_t);

void swpixel(gframe_pv const fp, uint32_t const color,
             uint16_t const x, uint16_t const y)
{
//  *PIX_PTR(fp, x, y) = color;
    printf("%4d %4d\n", x,y);
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

void line_UI32(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    BOOL const incY = (y1 > y0);
    uint32_t const offY = (incY) ? 1 : 0xFFFFFFFF; //Y addend fake-signed (pos/"neg" one)
    uint32_t const errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    uint32_t const negY = (~errY + 1); //Error addend fake-signed (arrange "<=" 0)
    uint32_t const errX = (x1 - x0); //Error addend; (assumed >= 0)
    uint32_t const posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)

    uint32_t error = (errX >> 1); //error is s30.1 fixed-point signed (guaranteed >= 0)
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        //FORK (parallel)
        uint32_t const errorA = error + negY;
        uint32_t const errorB = error + posX;
        uint32_t const nextX = x + 1;
        swpixel(fp,color, x,y);
        //JOIN
        //FORK (parallel)
        error = (errorA & 0x80000000) ? errorB : errorA;
        if (errorA & 0x80000000) y += offY;
        x = nextX;
        //JOIN
    }
}

void line_MINI(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    BOOL const incY = (y1 > y0);
    uint32_t const errX = (x1 - x0); //Error addend; (assumed >= 0)
    uint32_t const errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    int32_t const offY = (incY) ? 1 : -1; //Y addend signed (pos/neg one)
    int32_t const negY = (-errY); //Error addend signed (arrange <= 0)
    int32_t const posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)

    int32_t error = (int32_t)(errX >> 1); //error signed (guaranteed >= 0)
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        //FORK (parallel)
        int32_t const errorA = error + negY;
        int32_t const errorB = error + posX;
        int32_t const nextX = x + 1;
        swpixel(fp,color, x,y);
        //JOIN
        //FORK (parallel)
        error = (errorA < 0) ? errorB : errorA;
        if (errorA < 0) y += offY;
        x = nextX;
        //JOIN
    }
}

void line_FLAT(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        swpixel(fp,color, x,y);
        x++;
    }
}

#define ABSDIF(A,B) (((A) < (B)) ? ((B)-(A)) : ((A)-(B)))

void line_FULL(
    gframe_pv const fp, uint32_t const color,
    uint16_t const x0, uint16_t const y0,
    uint16_t const x1, uint16_t const y1)
{
    BOOL const steep = (ABSDIF(y1,y0) > ABSDIF(x1,x0)) ? 1 : 0;
    uint16_t a0, a1, b0, b1;
    if (steep) {
        a0 = y0; b0 = x0; //swap_u16(&x0, &y0);
        a1 = y1; b1 = x1; //swap_u16(&x1, &y1);
    } else {
        a0 = x0; b0 = y0;
        a1 = x1; b1 = y1;
    }
    if (a0 > a1) {
        uint16_t tmp;
        tmp=a0; a0=a1; a1=tmp; //swap_u16(&a0, &a1);
        tmp=b0; b0=b1; b1=tmp; //swap_u16(&b0, &b1);
    }
    int32_t const offY = (b0 < b1) ? 1 : -1;
    int32_t const deltax = (a1 - a0); //Guaranteed >= 0
    int32_t const deltay = ABSDIF(b1,b0);

    int32_t error = (int32_t)(deltax >> 1); //deltax / 2
    uint16_t x = a0, y = b0;
    while (x <= a1) {
        swpixel(fp,color, ((steep) ? y : x),((steep) ? x : y));
        error = error - deltay;
        if (error < 0) {
            error += deltax;
            y += offY;
        }
        x++;
    }
}


void swap_u16(uint16_t* a, uint16_t* b) {
  uint16_t tmp = *a;
  *a = *b;
  *b = tmp;
}

// Code from Wikipedia
void line_ORIG(
    gframe_pv const fp, uint32_t const color,
    uint16_t x0, uint16_t y0,
    uint16_t x1, uint16_t y1)
{
    char steep = (abs(y1-y0) > abs(x1-x0)) ? 1 : 0;
    if (steep) {
        swap_u16(&x0, &y0);
        swap_u16(&x1, &y1);
    }
    if (x0 > x1) {
        swap_u16(&x0, &x1);
        swap_u16(&y0, &y1);
    }
    int deltax = x1 - x0;
    int deltay = abs(y1-y0);
    int error = deltax / 2;
    int ystep;
    int y = y0;
    int x;
    ystep = (y0 < y1) ? 1 : -1;
    for ( x = x0; x <= x1; x++ ) {
        if (steep)
            swpixel(fp,color, y,x);
        else
            swpixel(fp,color, x,y);
        error = error - deltay;
        if( error < 0 ) {
            y += ystep;
            error += deltax;
        }
    }
}


void usage() {
    printf("./le < [style#] x0 y0 x1 y1 > | < style# >\n");
    exit(0);
}

int main(int argc, char** argv) {
    int x0,y0, x1,y1;
    line_FUNC style_ptr;
    char *style_name;
    int style_num = 0;

    switch (argc-1) { //argv[0] is process name, adjust argc for "extra arguments" we care about
        case 5: {
            style_num = atoi(argv[5]);
        } //Fallthrough
        case 4: {
            x0 = atoi(argv[1]);  x1 = atoi(argv[3]);
            y0 = atoi(argv[2]);  y1 = atoi(argv[4]);
        } break;
        case 1: {
            x0=2;  x1=10;
            y0=4;  y1=6;
            style_num = atoi(argv[1]);
        } if (style_num) break; //else Fallthrough
        default: {
            usage();
        }
    }

    switch (style_num) {
        case 1: { style_name = "LIVE";  style_ptr = &swline; } break;
        case 2: { style_name = "UI32";  style_ptr = &line_UI32; } break;
        case 3: { style_name = "MINI";  style_ptr = &line_MINI; } break;
        case 4: { style_name = "FLAT";  style_ptr = &line_FLAT; } break;
        case 5: { style_name = "FULL";  style_ptr = &line_FULL; } break;
        case 6: { style_name = "ORIG";  style_ptr = &line_ORIG; } break;
        default: {
            printf("\nUnrecognized style#%d.\n", style_num);
        } //Fallthrough
        case 0: {
            return 1;
        }
    }

    printf("\n%s#%d: (%4d,%4d) => (%4d,%4d)\n",
           style_name,style_num, x0,y0, x1,y1);
    (*style_ptr)(0,style_num, x0, y0, x1, y1);

    return 0;
}
