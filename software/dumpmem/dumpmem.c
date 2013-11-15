// #define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
// #define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))
#define _tran_wait \
	{ while (!TRAN_CTRL); }
#define _tran_out(CH) \
	{ TRAN_DATA = ((unsigned int)CH); }
#define _tran_ch(CH) \
	{ _tran_wait; _tran_out(CH); }

#define DSTR "This is just a simple test. Memory contents are echoed to UART constantly. Ideally the values will make it. Reset can be an issue but we shall cee (sic).  "

const char rodata[] = "READONLY: " DSTR;
char data[] = "xyz pdq: UNSEEN"; //Not initialized unless loader or _start do something


void send_ch(char ch)
{
	_tran_ch(ch & 0x000000FF);
}

void mem_xfer(char *dp, const char *sp)
{
	for ( ; (*dp++ = *sp++) != 0 ; );
}

int main(void) // Could have _start pass basic memory info (base/stack pointers)
{
	_tran_ch(' '); _tran_ch(']'); _tran_ch('['); _tran_ch(' ');
	send_ch(' '); send_ch('<'); send_ch('>'); send_ch(' ');
	mem_xfer(data, rodata); // "cp" is const, but we overwrite mem here

	const char *cp = ((const char *)data);
L_EVERMORE:
	send_ch( *cp++ ); // This rolls over (and hopefully back "around")
	goto L_EVERMORE;
}
