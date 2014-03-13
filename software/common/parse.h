#ifndef PARSE_H_
#define PARSE_H_

#include "types.h"

int8_t* read_n(int8_t* b, uint32_t n);
int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds);

void store(uint32_t address, uint32_t length);
void show_block(uint32_t* address, uint8_t numWords);
uint32_t copy_xor(uint32_t *pSRC, uint32_t *pDST, uint32_t length);


#define BUFFER_FIX ((int8_t*)0x10000100) //FIXED location "global"
#define BUFFER_LEN (0x00000080) //128-bytes

 int8_t* tok_word  ( void );
uint32_t tok_hex32u( void );
uint16_t tok_hex16u( void );
uint8_t  tok_hex8u ( void );
uint32_t tok_dec32u( void );
uint16_t tok_dec16u( void );
uint8_t  tok_dec8u ( void );

void bufw_newline( void );
void bufw_hex32u(uint32_t u32);
void bufw_hex16u(uint16_t u16);
void bufw_hex8u ( uint8_t u8 );

#endif
