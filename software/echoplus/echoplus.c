#define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
#define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

void RECV_wait()
{
	while (!RECV_CTRL) ;
}

void TRAN_wait()
{
	while (!TRAN_CTRL) ;
}

unsigned char RECV_byte()
{
	unsigned char ib = 0;
	
	RECV_wait();
	ib = RECV_DATA;
	return ib;
}

void TRAN_byte(unsigned char ob)
{
	TRAN_wait();
	TRAN_DATA = ob;
	TRAN_wait(); // Choosing to wait until send "completes"!
}

void TRAN_cstr(const char *str)
{
	const char *sp = str;
	unsigned char ob;
	while ( (ob = *sp++) != 0) {
		TRAN_wait();
		TRAN_DATA = ob;
	}
	TRAN_wait(); // Choosing to wait until last send "completes"!
}


int main(void)
{
	TRAN_byte('>');
	unsigned char offset = 0;
	for ( ; ; ) {
		TRAN_cstr("\r\n\r\n### ECHOPLUS ###\r\n\r\n");
		for ( ; ; ) {
			unsigned char bb = RECV_byte();
			if (bb == 0x01) break; // CTRL-A to advance
			TRAN_byte(bb + offset);
		}
		if (++offset > 5) break;
	}
	return 0;
}
