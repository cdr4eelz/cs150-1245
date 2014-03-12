#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define uint32_t unsigned int
#define int32_t int
#define uint16_t unsigned short
#define int16_t short

#define SWAP(A,B,T) {T=A;A=B;B=T;}
#define ABSDIF(A,B) (((A) < (B)) ? ((B)-(A)) : ((A)-(B)))

void swap(int*, int*);
void line1(int, int, int, int);
void line2(uint16_t, uint16_t, uint16_t, uint16_t);
void usage();

int main(int argc, char** argv) {
  if(argc < 5)
    usage();
  int x0 = atoi(argv[1]);
  int y0 = atoi(argv[2]);
  int x1 = atoi(argv[3]);
  int y1 = atoi(argv[4]);

  printf("\nLINE1: (%4d,%4d) => (%4d,%4d)\n", x0,y0, x1,y1);
  line1(x0, y0, x1, y1);
  printf("\nLINE2: (%4d,%4d) => (%4d,%4d)\n", x0,y0, x1,y1);
  line2(x0, y0, x1, y1);
  return 0;
}

void usage() {
  printf("./le x0 y0 x1 y1\n");
  exit(0);
}

void swap(int* a, int* b) {
  int tmp = *a;
  *a = *b;
  *b = tmp;
}

// Code from Wikipedia
void line1(int x0, int y0, int x1, int y1) {
  char steep = (abs(y1-y0) > abs(x1-x0)) ? 1 : 0; 
  if(steep) {
    swap(&x0, &y0);
    swap(&x1, &y1);
  }
  if( x0 > x1 ) {
    swap(&x0, &x1);
    swap(&y0, &y1);
  }
  int deltax = x1 - x0;
  int deltay = abs(y1-y0);
  int error = deltax / 2;
  int ystep;
  int y = y0;
  int x;
  ystep = (y0 < y1) ? 1 : -1;
  for( x = x0; x <= x1; x++ ) {
    if(steep)
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

// Based on wikipedia implementation
void line2(//uint32_t const frame, uint32_t const color,
            uint16_t const x0, uint16_t const y0,
            uint16_t const x1, uint16_t const y1)
{
//  uint32_t* const fp = FRAME_PTR(frame);
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
    uint16_t x = a0;
    for ( ; x <= a1; x++) {
        if (steep) {
            printf("%4d %4d\n", y, x);
//          swpixel(frame, color, y, x);
//          *PIX_PTR(fp, y, x) = color;
        } else {
            printf("%4d %4d\n", x, y);
//          swpixel(frame, color, x, y);
//          *PIX_PTR(fp, x, y) = color;
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
