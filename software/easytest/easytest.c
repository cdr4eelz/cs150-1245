// #define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
// #define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define _tran_wait \
	{ while (!TRAN_CTRL); }
//First version writing 4-bytes (hw uses only low byte)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))
#define _tran_out(CH) \
	{ TRAN_DATA = ((unsigned int)CH); }
#define _tran_ch(CH) \
	{ _tran_wait; _tran_out(CH); }
//Second version writing only the low byte (no difference expected)
#define TRAN_DATA2 (*((volatile unsigned char*)0x8000000B))
#define _tran_out2(CH) \
	{ TRAN_DATA2 = ((unsigned char)CH); }
#define _tran_ch2(CH) \
	{ _tran_wait; _tran_out2(CH); }


__attribute__ ((aligned))
const char rodata[] = "ReaDoNLy: Simple test. Memory contents are echoed to UART constantly. Ideally the values will make it. Reset can be an issue but we shall cee.  ";
//char data[] = "xyz pdq: UNSEEN"; //Not initialized unless loader or _start do something

//NOTE: This is coded awkwardly in order to minimize reads from memory during preamble
//      which helps confirm simple serial link operation (rather than memory testing).


void send_ch(char ch) { _tran_ch(ch & 0x000000FF); }

#if 0
void send8(char *sp) { //KISS Version
	_tran_ch(*sp++); _tran_ch(*sp++);
	send_ch(*sp++); _tran_ch2(*sp++);
	_tran_ch(*sp++); _tran_ch(*sp++);
	_tran_ch2(*sp++); _tran_ch(*sp++);
}

void mem_xfer16(unsigned int *dp, const unsigned int *sp) {
	unsigned int *dp_w;
	unsigned short *dp_h;
	unsigned char *dp_b;
	const unsigned int *sp_w;
	const unsigned short *sp_h;
	const unsigned char *sp_b;

	dp_w = (unsigned int *)dp;
	sp_w = (const unsigned int *)sp;
	*dp_w++ = *sp_w++; *dp_w++ = *sp_w++; //2 x 4-bytes
	dp_h = (unsigned short *)dp_w;
	sp_h = (const unsigned short *)sp_w;
	*dp_h++ = *sp_h++; *dp_h++ = *sp_h++; //2 x 2-bytes
	dp_b = (unsigned char *)dp_h;
	sp_b = (const unsigned char *)sp_h;
	*dp_b++ = *sp_b++; *dp_b++ = *sp_b++; //2 x 1-byte
	*dp_b++ = *sp_b++; *dp_b++ = *sp_b++; //2 x 1-byte
}

void mem_xfer(unsigned char *dp, const unsigned char *sp, int bytes) {
	while (bytes--) *dp++ = *sp++;
}

void ptr_check() {
	const char *cp = rodata;
	send_ch(*cp++);
	send_ch(cp[0]); send_ch(cp[1]);
	send_ch(*cp++);
}
#endif

int main() {
	_tran_ch(']'); _tran_ch2('[');
	send_ch(']'); send_ch('[');
	
#if 0
	_tran_ch('@');
	send_ch(rodata[3]); send_ch(rodata[4]); send_ch(rodata[0]); send_ch(rodata[7]);
	
	_tran_ch('#');
	ptr_check();

	_tran_ch('$');
	mem_xfer16( (unsigned int *)0x50000100, (const unsigned int *)rodata);
	_tran_ch(*((char *)0x50000100));
	_tran_ch('>');
	send8( (char *)0x50000107 );

	_tran_ch('%');
	mem_xfer16( ((unsigned int *)0x10000100), (const unsigned int *)rodata);
	_tran_ch(*((char *)0x10000100));
	_tran_ch('>');
	send8( ((char *)0x10000107) );

	_tran_ch('!'); _tran_ch('B'); _tran_ch('y'); _tran_ch('e');
	_tran_ch('\n');
	int countdown = 32;
	while (countdown--) _tran_ch('+');
	_tran_ch('\n');
#endif
        return 0;
L_EVERMORE:
	goto L_EVERMORE;
}
