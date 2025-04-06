#define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
#define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))
#define _tran_wait \
	{ while (!TRAN_CTRL); }
#define _tran_out(CH) \
	{ TRAN_DATA = ((unsigned int)CH); }
#define _tran_ch(CH) \
	{ _tran_wait; _tran_out(CH); }

#define DSTR "This is just a simple test. Memory contents are echoed to UART constantly. Ideally the values will make it. Reset can be an issue but we shall cee (sic).  "

__attribute__ ((aligned))
const char rodata[] = "ReaDoNLy: " DSTR;

__attribute__ ((aligned))
char data[] = "xyz pdq: UNSEEN"; //Not initialized unless loader or _start do something

//NOTE: This is coded awkwardly in order to minimize reads from memory during preamble
//      which helps confirm simple serial link operation (rather than memory testing).


void send_ch(unsigned char ch) { _tran_ch(ch & 0x000000FF); }

void mem_xfer4(unsigned int *dp, const unsigned int *sp, int len) {
	while (len--) *dp++ = *sp++;
}

void ptr_check() {
	const char *cp = rodata;
	send_ch(cp[0]); send_ch(cp[1]); send_ch(cp[2]); send_ch(cp[3]);
	_tran_ch('-');
	send_ch(*cp++); send_ch(*cp++); send_ch(*cp++); send_ch(*cp++);
}

unsigned char nibble_char(unsigned char num) {
	unsigned char t = num & 0x0f;
	if (t >= 0 && t <= 9) {
		return '0' + t;
	} else if (t >= 0xa && t <= 0xf) {
		return 'a' + (t - 0xa);
	}
	return '?';
}

void send_byte_hex(unsigned char const u8)
{
	send_ch(nibble_char(u8 >> 4)); //High nibble
	send_ch(nibble_char(u8));      //Low nibble
}

int main(void) {
// SKIP THE ECHO PHASE so there is no interaction needed
//	unsigned char byte = '>';
//	while (byte != 0x03) {
//		send_ch( byte );
//		while (!RECV_CTRL);
//		byte = RECV_DATA;
//	}
	
	_tran_ch('@');
	send_ch(' '); send_ch('<'); send_ch('>'); send_ch(' ');
	
	_tran_ch('#');
	send_ch(rodata[0]);
	_tran_ch('-');
	send_ch(rodata[4]);
	
	_tran_ch('%');
	//	mem_xfer4( ((unsigned int *)0x10000000), (const unsigned int *)rodata, 8);
	//const char *cm = (const char *)(0x10000000);
	_tran_ch('\n');
	_tran_ch('\n');
	_tran_ch('&');
	const char *cm = rodata; //(const char *)(rodata);

	for (int cnt = 40; cnt > 0; cnt--) {
		_tran_ch('+');
		send_ch( *cm++ ); // This rolls over (and hopefully back "around")
	}

	_tran_ch('\n');
	_tran_ch('\n');

	cm = (const char *)(0x10000000); //Dump from DDR-MIG memory, to provoke intermittent stall-freeze...
	for (int cnt = 1024 * 10; cnt > 0; cnt--) { // Max of 10K bytes dumped as hex
		if (!((unsigned int)cm % 16)) {
			send_ch('\n'); send_ch('\r');
		} else if (!((unsigned int)cm % 4)) {
			send_ch(' ');
		}
		send_byte_hex( *cm++ );
	}
	_tran_ch('\n');
	_tran_ch('\n');

}
