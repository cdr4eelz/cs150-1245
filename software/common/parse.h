#ifndef PARSE_H_
#define PARSE_H_

#include "types.h"

typedef enum bcmd_e {
    BC_UNKNOWN,
    BC_FILE, BC_JAL,
    BC_LW, BC_LHU, BC_LBU,
    BC_SW, BC_SH, BC_SB,
    BC_DUMP, BC_COPY,
    BC_GS, BC_SC, BC_GC, BC_CC,
    BC_FF, BC_PF, BC_GF, BC_SF, BC_GP,
    BC_ARGB, BC_FILL, BC_LINE, BC_PIXL, BC_ELIP,
    BC_CIRC
} bcmd_t;

typedef enum radixize_e {
    RZ_HEX32, RZ_HEX16, RZ_HEX8,
    RZ_DEC32, RZ_DEC16, RZ_DEC8
} radixize_t;

int8_t* read_n(int8_t* bufptr, uint32_t buflen);
int8_t* read_token(int8_t* bufptr, uint32_t buflen, const int8_t* ds);
bcmd_t cmd_token(const int8_t* const bufptr);

void store(volatile uint32_t *address, uint32_t numbytes);
void dump_block(uint32_t* address, uint8_t numWords);
uint32_t copy_xor(uint32_t *pSRC, uint32_t *pDST, uint32_t length);


//FIXED location "globals"!  Watchout :)
#define STASH_ADDR ((void**)0x10000200)

void* tok_addr( void );
uint32_t tok_radnum(radixize_t rz);
void bufw_radnum(radixize_t rz, uint32_t u32);
void bufw_newline( void );

#define tok_hex32u()    ((uint32_t)tok_radnum( RZ_HEX32 ))
#define tok_hex16u()    ((uint16_t)tok_radnum( RZ_HEX16 ))
#define tok_hex8u()      ((uint8_t)tok_radnum( RZ_HEX8 ))
#define tok_dec32u()    ((uint32_t)tok_radnum( RZ_DEC32 ))
//#define tok_dec16u()    ((uint16_t)tok_radnum( RZ_DEC16 ))
uint16_t tok_dec16u();
#define tok_dec8u()      ((uint8_t)tok_radnum( RZ_DEC8 ))

#define bufw_hex32u(U32)  bufw_radnum(RZ_HEX32,(uint32_t)(U32))
#define bufw_hex16u(U16)  bufw_radnum(RZ_HEX16,(uint32_t)(U16))
#define bufw_hex8u(U8)     bufw_radnum(RZ_HEX8,(uint32_t)(U8))

#endif
