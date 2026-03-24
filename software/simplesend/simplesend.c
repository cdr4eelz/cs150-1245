
#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

void _start(void) // Could ahve _start pass some basic info
{
	L_FOREVER:
		while (!TRAN_CTRL); TRAN_DATA = '[';
		while (!TRAN_CTRL); TRAN_DATA = '.';
		while (!TRAN_CTRL); TRAN_DATA = ']';
	goto L_FOREVER;
}
