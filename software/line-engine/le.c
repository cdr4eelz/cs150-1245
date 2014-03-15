#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef int   int32_t;
typedef short int16_t;
//typedef char  int8_t;
typedef unsigned int   uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char  uint8_t;

typedef void (*line_FUNC)(uint16_t, uint16_t, uint16_t, uint16_t);

#define SWAP(A,B,T) {T=A;A=B;B=T;}
#define ABSDIF(A,B) (((A) < (B)) ? ((B)-(A)) : ((A)-(B)))


void line_LIVE(
  //const uint32_t frame, const uint32_t color,
    const uint16_t x0, const uint16_t y0,
    const uint16_t x1, const uint16_t y1)
{
}

void line_UI32(
    const uint16_t x0, const uint16_t y0,
    const uint16_t x1, const uint16_t y1)
{
    const char incY = (y1 > y0);
    const uint32_t errX = (x1 - x0); //Error addend; (assumed >= 0)
    const uint32_t errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    const uint32_t offY = (incY) ? 1 : 0x80000000; //Y addend fake-signed (pos/"neg" one)
    const uint32_t negY = (0x80000000 | errY); //Error addend fake-signed (arrange "<=" 0)
    const uint32_t posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)

    uint32_t error = (errX >> 1); //error is s30.1 fixed-point signed (guaranteed >= 0)
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        //FORK (parallel)
        const uint32_t errorA = error + negY;
        const uint32_t errorB = error + posX;
        const uint32_t nextX = x + 1;
        printf("%4d %4d\n", x, y);
        //JOIN
        //FORK (parallel)
        error = (errorA & 0x80000000) ? errorB : errorA;
        if (errorA & 0x80000000) y += offY;
        x = nextX;
        //JOIN
    }
}

void line_MINI(
    const uint16_t x0, const uint16_t y0,
    const uint16_t x1, const uint16_t y1)
{
    const char incY = (y1 > y0);
    const uint32_t errX = (x1 - x0); //Error addend; (assumed >= 0)
    const uint32_t errY = (incY) ? (y1 - y0) : (y0 - y1); //Error subtracted portion (arrange >= 0)
    const int32_t offY = (incY) ? 1 : -1; //Y addend signed (pos/neg one)
    const int32_t negY = (-errY); //Error addend signed (arrange <= 0)
    const int32_t posX = (errX + negY); //Error addend signed, net after errX/2 (guaranteed >= 0)

    int32_t error = (int32_t)(errX >> 1); //error signed (guaranteed >= 0)
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        //FORK (parallel)
        const int32_t errorA = error + negY;
        const int32_t errorB = error + posX;
        const int32_t nextX = x + 1;
        printf("%4d %4d\n", x, y);
        //JOIN
        //FORK (parallel)
        error = (errorA < 0) ? errorB : errorA;
        if (errorA < 0) y += offY;
        x = nextX;
        //JOIN
    }
}

void line_FLAT(
    const uint16_t x0, const uint16_t y0,
    const uint16_t x1, const uint16_t y1)
{
    uint16_t x = x0, y = y0;
    while (x <= x1) {
        printf("%4d %4d\n", x, y);
        x++;
    }
}


void line_FULL(
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
    const int32_t offY = (b0 < b1) ? 1 : -1;
    const int32_t deltax = (a1 - a0); //Guaranteed >= 0
    const int32_t deltay = ABSDIF(b1,b0);

    int32_t error = (int32_t)(deltax >> 1); //deltax / 2
    uint16_t x = a0, y = b0;
    while (x <= a1) {
        printf("%4d %4d\n", (steep) ? y : x, (steep) ? x : y);
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
void line_ORIG(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1) {
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
            printf("%4d %4d\n", y, x);
        else
            printf("%4d %4d\n", x, y);
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
        case 1: { style_name = "LIVE";  style_ptr = &line_LIVE; } break;
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
    (*style_ptr)(x0, y0, x1, y1);

    return 0;
}
