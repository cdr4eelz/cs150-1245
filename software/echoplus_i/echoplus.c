#include "uart.h"

void RECV_wait()
{
	while (!URECV_CTRL) ;
}

void TRAN_wait()
{
	while (!UTRAN_CTRL) ;
}

unsigned char RECV_byte()
{
	unsigned char ib = 0;
	
	RECV_wait();
	ib = URECV_DATA;
	return ib;
}

void TRAN_byte(unsigned char ob)
{
	TRAN_wait();
	UTRAN_DATA = ob;
	TRAN_wait(); // Choosing to wait until send "completes"!
}

void TRAN_cstr(const char *str)
{
	const char *sp = str;
	unsigned char ob;
	while ( (ob = *sp++) != 0) {
		TRAN_wait();
		UTRAN_DATA = ob;
	}
	TRAN_wait(); // Choosing to wait until last send "completes"!
}


const char greeting[] = "\r\n\r\n### ECHOPLUS ###\r\n\r\n";
int max_loops = 2;

int main(void)
{
	TRAN_byte('>');
	unsigned char offset = 0;
	for ( ; ; ) {
		TRAN_cstr(greeting);
		for ( ; ; ) {
			unsigned char bb = RECV_byte();
			if (bb == 0x01) break; // CTRL-A to advance
			TRAN_byte(bb + offset);
		}
		if (++offset > max_loops) break;
	}
	max_loops++;
	return 0;
}
