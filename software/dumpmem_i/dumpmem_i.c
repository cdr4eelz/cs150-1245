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

const char rodata[] = "ReaDoNLy: " DSTR;
char data[] = "xyz pdq: UNSEEN"; //Not initialized unless loader or _start do something

//NOTE: This is coded awkwardly in order to minimize reads from memory during preamble
//      which helps confirm simple serial link operation (rather than memory testing).


void send_ch(char ch) { _tran_ch(ch & 0x000000FF); }

void mem_xfer4(unsigned int *dp, const unsigned int *sp, int len) {
	while (len--) *dp++ = *sp++;
}

void ptr_check() {
	const char *cp = rodata;
	send_ch(cp[0]); send_ch(cp[1]); send_ch(cp[2]); send_ch(cp[3]);
	_tran_ch('-');
	send_ch(*cp++); send_ch(*cp++); send_ch(*cp++); send_ch(*cp++);
}

int main(void) { // Could have _start pass basic memory info (base/stack pointers)
//	_tran_ch('|');
//	_tran_ch('-'); _tran_ch(']'); _tran_ch('['); _tran_ch('-');
	
	_tran_ch('@');
	send_ch(' '); //send_ch('<'); send_ch('>'); send_ch(' ');
	
	_tran_ch('#');
	send_ch(rodata[0]); //send_ch(rodata[1]); send_ch(rodata[2]); send_ch(rodata[3]);
	_tran_ch('-');
	send_ch(rodata[4]); //send_ch(rodata[5]); send_ch(rodata[6]); send_ch(rodata[7]);
//	_tran_ch('#');
	
//	_tran_ch('$');
//	ptr_check();
//	_tran_ch('$');

	_tran_ch('%');
	mem_xfer4( ((unsigned int *)0x10000000), (const unsigned int *)rodata, 8);
	
//	_tran_ch('^'); _tran_ch('<'); _tran_ch('v'); _tran_ch('>');
	const char *cm = (const char *)(0x10000000);
	_tran_ch('&');

	for (int cnt = 8 * 4; cnt > 0; cnt++) {
		_tran_ch(',');
		send_ch( *cm++ ); // This rolls over (and hopefully back "around")
	}
L_EVERMORE:
	goto L_EVERMORE;
}
