#ifndef PARSE_H_
#define PARSE_H_

#include "types.h"

typedef enum bcmd_e {
    BC_UNKNOWN, BC_BLANK, BC_HELP,
    BC_FILE, BC_JAL, BC_DUMP, BC_COPY,
    BC_LW, BC_LHU, BC_LBU,
    BC_SW, BC_SH,  BC_SB,
    BC_GSTAT, BC_GCODE, BC_FRAME, BC_COLOR,
    BC_FILL, BC_LINE, BC_PIXL, BC_ELIP, BC_CIRC
} bcmd_t;

typedef struct bcmdspec_s {
    const int8_t *token;
    bcmd_t        cmd;
    uint16_t      flags;
} const bcmdspec_t;

extern bcmdspec_t const cmd_table[];
extern const int8_t const DEF_DELIMS[], *ERRS_ALIGN;

typedef enum radixize_e {
    RZ_HEX32, RZ_HEX16, RZ_HEX8,
    RZ_DEC32, RZ_DEC16, RZ_DEC8
} radixize_t;

int8_t* read_n(int8_t* bufptr, uint32_t numBytesBeforeNull);
int8_t* read_token(int8_t* bufptr, uint32_t buflen,
                   const int8_t* delimstr); //NULL to use DEF_DELIMS
bcmdspec_t* token_cmdspec(const int8_t* bufptr);
void bufw_cmdspec( void );

void store(uint32_t *pDST, uint32_t numBytes);
const uint32_t* dump_block(const uint32_t* pSRC, uint8_t numWords);
uint32_t copy_xor(const uint32_t* pSRC, uint32_t numBytes,
                  uint32_t* pDST); //NULL to xor without copy


void* tok_addr( void* *stash_addr ); //NULL for unused stash_addr

uint32_t tok_radnum(radixize_t rz);
#define tok_hex32u()    ((uint32_t)tok_radnum(RZ_HEX32))
#define tok_hex16u()    ((uint16_t)tok_radnum(RZ_HEX16))
#define tok_hex8u()      ((uint8_t)tok_radnum(RZ_HEX8))
#define tok_dec32u()    ((uint32_t)tok_radnum(RZ_DEC32))
#define tok_dec16u()    ((uint16_t)tok_radnum(RZ_DEC16))
#define tok_dec8u()      ((uint8_t)tok_radnum(RZ_DEC8))

void bufw_newline( void );
void bufw_radnum(radixize_t rz, uint32_t u32);
#define bufw_hex32u(U32)  bufw_radnum(RZ_HEX32,(uint32_t)(U32))
#define bufw_hex16u(U16)  bufw_radnum(RZ_HEX16,(uint32_t)(U16))
#define bufw_hex8u(U8)     bufw_radnum(RZ_HEX8,(uint32_t)(U8))

#endif
