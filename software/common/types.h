#ifndef TYPES_H_
#define TYPES_H_

/* OLD hard coded integer type definitions for the two architectures...
//MIPS32 types:
typedef signed char         int8_t;
typedef unsigned char       uint8_t;
typedef short int           int16_t;
typedef short unsigned int  uint16_t;
typedef int                 int32_t;
typedef unsigned int        uint32_t;
typedef unsigned int        size_t;
typedef int                 ptrdiff_t;
typedef int                 intptr_t;
typedef unsigned int        uintptr_t;
...
//X86_64 types, though perhaps just include <stdint.h> instead of custom???
typedef signed char         int8_t;
typedef unsigned char       uint8_t;
typedef short               int16_t;
typedef unsigned short      uint16_t;
typedef int                 int32_t;
typedef unsigned int        uint32_t;
typedef long unsigned int   size_t;
typedef long int            ptrdiff_t;
typedef long int            intptr_t;
typedef long unsigned int   uintptr_t;
*/

// Use GCC custom integer types so MIPS32 and X86_64 have appropriate defs:
typedef __INT8_TYPE__       int8_t;
typedef __UINT8_TYPE__      uint8_t;
typedef __INT16_TYPE__      int16_t;
typedef __UINT16_TYPE__     uint16_t;
typedef __INT32_TYPE__      int32_t;
typedef __UINT32_TYPE__     uint32_t;
typedef __SIZE_TYPE__       size_t;
typedef __PTRDIFF_TYPE__    ptrdiff_t;
typedef __INTPTR_TYPE__     intptr_t;
typedef __UINTPTR_TYPE__    uintptr_t;

#define NULL  ((void*)0)
typedef int   BOOL;
#define TRUE  (1)
#define FALSE (0)

#define HILO16(x, y) ((((x) & 0xFFFF) << 16) | ((y) & 0xFFFF))

#define HI16(x) (((x) >> 16) & 0xFFFF)
#define LO16(x) ((x) & 0xFFFF)

#define HILO8(x, y) ((((x) & 0xFF) << 8) | ((y) & 0xFF))

#define HI8(x) (((x) >> 8) & 0xFF)
#define LO8(x) ((x) & 0xFF)

#define HILO4(x, y) ((((x) & 0xF) << 4) | ((y) & 0xF))

#define HI4(x) (((x) >> 4) & 0xF)
#define LO4(x) ((x) & 0xF)

#endif
