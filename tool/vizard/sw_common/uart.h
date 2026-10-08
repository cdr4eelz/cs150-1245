#ifndef UART_H_
#define UART_H_

#include "types.h"
#include "mmio_intr_cop0.h"

#define URECV_CTRL (*((volatile uint32_t*)MM_UARX_VALID) & MM_UART_RVA_BIT)
#define URECV_DATA (*((volatile uint32_t*)MM_UARX_DATA) & MM_UART_DATA_BYTE)

#define UTRAN_CTRL (*((volatile uint32_t*)MM_UATX_READY) & MM_UART_RVA_BIT)
#define UTRAN_DATA (*((volatile uint32_t*)MM_UATX_DATA)) //LVALUE

#define _tran_wait \
	{ while (!UTRAN_CTRL); }
#define _tran_out(CH) \
	{ UTRAN_DATA = (((uint32_t)CH) & MM_UART_DATA_BYTE); }
#define _tran_ch(CH) \
	{ _tran_wait; _tran_out(CH); }


void uwrite_int8(int8_t c);
void uwrite_int8s(const int8_t* s);
int8_t uread_int8(void);

#endif
