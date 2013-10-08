// #define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
// #define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

const char someStr[] = "This is just a simple test. Memory contents are echoed to UART constantly. Ideally the values will make it. Reset can be an issue but we shall cee (sic).  ";

int main(void)
{
	const char *cp = someStr;
	for ( ; ; ) {
		while (!TRAN_CTRL) ;
		TRAN_DATA = *cp++;
	}
	return 0;
}
