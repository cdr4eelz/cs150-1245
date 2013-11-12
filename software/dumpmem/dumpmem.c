// #define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
// #define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

#define DSTR "This is just a simple test. Memory contents are echoed to UART constantly. Ideally the values will make it. Reset can be an issue but we shall cee (sic).  "
const char rodata[] = "READONLY: " DSTR;
char data[] = "xyz";

void send(char ch);
void copy(char *dest, const char*source);


int main(void) // Could ahve _start pass some basic info
{
	const *cp = (const char *)data;

	do {
		send(']'); send('[');
	} while (1);
	copy(data, rodata);
	
	for ( ; ; ) send(*cp++);

	return 0;
}

void send(char ch)
{
	while (!TRAN_CTRL);
	TRAN_DATA = (unsigned char)ch;
}

void copy(char *dp, const char *sp)
{
	for ( ; (*dp++ = *sp++) != 0 ; );
}
