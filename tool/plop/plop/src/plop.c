#include <string.h>
#include <stdio.h>

#include "platform.h"
#include "xparameters.h"
#include "xuartlite_l.h"
//#include <xiomodule.h>
#include "xil_types.h"
#include "xil_assert.h"
#include "xil_printf.h"
#include "xstatus.h"


#define U_DEFAULT   STDIN_BASEADDRESS
#define U_DEBUG     XPAR_MDM_0_BASEADDR
//#define U_CABLE     XPAR_RS232_UART_1_BASEADDR
#define U_MIPSY     XPAR_RS232_UART_2_BASEADDR

/*
inline u32 pumpBytes_raw(int u_RX, int u_TX, u8 nl2cr, u16 maxBurst)
{
    u16 count = 0;
    while (!XUartLite_IsReceiveEmpty(u_RX)) {
        if (XUartLite_IsTransmitFull(u_TX))
            { return (0x01000000 | count); }
        if (count >= maxBurst)
            { return (0x00010000 | count); }
        u8 bX = XUartLite_RecvByte(u_RX);
        if (nl2cr && (bX=='\n'))
            { bX = '\r'; }
        XUartLite_SendByte(u_TX, bX);
        count++;
    }
    return (0x00000000 | count);
}
*/

// TODO: Use drop-in-replacements on circular-buffers equivalent to 4 XUartLite calls, then use pumpBytes_raw()
// TODO: Use hardware-FIFO & interrupts rather than software-polling FPGA borne CPU! :)
// TODO: Detect a stall (buffer not empty for too long) & reset UART & buffer.

u16 RxIntoBuf(u8 *pB, u8 *pW, u8 **ppH, u8 *pT, int u_RX, u8 nl2cr, u16 maxBurst) {
    u16 count = 0;
    while (maxBurst--) {
        u8 *pH = *ppH; // Local temp for head pointer
        // Can we check for error/overflow of UART?
        if ((pT != pH) && (pT == (pH+1))) {
            //TODO: Note the overrun (is xmit stalled?)
            break; // Would step on tail (redundant check common case)
        }
        if (XUartLite_IsReceiveEmpty(u_RX)) break; // Nothing incoming (no work to do)
        u8 bX = XUartLite_RecvByte(u_RX);
        if (nl2cr && (bX == '\n')) bX = '\r'; // Translate nl->cr if requested (inbound)
        *pH++ = bX; // Store into buffer & advance (post-increment)
        if (pH >= pW) pH = pB; // Wrap-around if needed (hopefully never >)
        *ppH = pH; // Update the real head pointer
    }
    return count;
}

u16 TxFromBuf(u8 *pB, u8 *pW, u8 *pH, u8 **ppT, int u_TX, u8 nl2cr, u16 maxBurst) {
    u16 count = 0;
    while (maxBurst--) {
        u8 *pT = *ppT; // Local temp for tail pointer
        if (pT == pH) break; // Buffer is empty (no work to do)
        if (XUartLite_IsTransmitFull(u_TX)) break; // We are behind (but not necessarily in trouble)
        u8 bX = *pT++; // Fetch from buffer & advance (post-increment)
        if (nl2cr && (bX == '\n')) bX = '\r'; // Translate nl->cr if requested (outbound)
        XUartLite_SendByte(u_TX, bX); // Get it closer to hardware ASAP (in case XMIT wasnt busy)
        if (pT >= pW) pT = pB; // Wrap-around if needed (hopefully never >)
        *ppT = pT; // Update the real head pointer
    }
    return count;
}


// --- GLOBALS --- (Tune linker to ensure heap/stack/code don't crowd out globals)
#define D2M_SIZE    (12 * 1024)
#define M2D_SIZE    ( 4 * 1024)
u8 D2M_BUF[D2M_SIZE];   // TODO: Figure out pragma to align to word (or bigger)
u8 M2D_BUF[M2D_SIZE];

int main()
{
    init_platform();

/*
    print("\r\n[PUMPIT.B]\n\r");
    u32 tally_D2M = 0, tally_M2D = 0;
    while ((tally_M2D & 0x0000FFFF) < (1*1024)) {
        tally_M2D += pumpBytes_raw(U_MIPSY, U_DEBUG, FALSE,  8);
        tally_D2M += pumpBytes_raw(U_DEBUG, U_MIPSY, TRUE, 128);
    }
*/

// Round-robin servicing of each pipe does a darn good job of keeping up.
// The key offender is the data coming in via JTAG (U_DEBUG.Rx) as the
// mdm jtag_uart_serial "terminal server" seems very latent &/| underbuffered.
// These burst "weights" may not do much (and might postpone the inevitable), but
// they are intended to postpone a logjam on the JTAG & mostly accomplish that
// by just using a huge buffer.  Not sure if the JTAG-SERIAL server honors XON/XOFF,
// but that would be worth trying!  Bottom line, having a huge buffer allows BIOS
// programming...and turning on printed debug output from "socat" can help give
// the mdm terminal server some breathing room too.
    print("\r\n[BUFFETTE.0]\r\n");

    u8 *pD2M_H = D2M_BUF, *pD2M_T = D2M_BUF, *pD2M_W = (D2M_BUF + D2M_SIZE);
    u8 *pM2D_H = M2D_BUF, *pM2D_T = M2D_BUF, *pM2D_W = (M2D_BUF + M2D_SIZE);

    u32 tally_D2M_Rx=0, tally_M2D_Rx=0, tally_D2M_Tx=0, tally_M2D_Tx=0;
    while (1) { //(tally_D2M_Tx < (2*1024)) {
        tally_D2M_Rx += RxIntoBuf(D2M_BUF, pD2M_W, &pD2M_H, pD2M_T, U_DEBUG, FALSE, 9);
        tally_D2M_Tx += TxFromBuf(D2M_BUF, pD2M_W, pD2M_H, &pD2M_T, U_MIPSY, TRUE , 5);
        tally_M2D_Rx += RxIntoBuf(M2D_BUF, pM2D_W, &pM2D_H, pM2D_T, U_MIPSY, FALSE, 3);
        tally_M2D_Tx += TxFromBuf(M2D_BUF, pM2D_W, pM2D_H, &pM2D_T, U_DEBUG, FALSE, 2);
    }

    print("\r\n[DONE]\r\n");

    cleanup_platform();
    return 0;
}

/* TEST DATA
0123456789 A
0123456789 B
0123456789 C ABcdefghiJKlmnopqrstuvwxYZABcdefghiJKlmnopqrstuvwxYZ
0123456789 D
0123456789 E ABcdefghijkLmnoPqrstuvwxyZABcdefghijkLmnoPqrstuvwxyZABcdefghijkLmnoPqrstuvwxyZ
0123456789 F
A 0123456789ABcdEfghijKlmnopqrstuvwxyZ
B 0123456789ABcdEfghijKlmnopqrstuvwxyZ ABcdEfghijKlmnopqrstuvwxyZABcdEfghijKlmnopqrstuvwxyZ
C 0123456789
D 0123456789ABcdEfghijKlmnopqrstuvwxyZABcdEfghijKlmnopqrstuvwxyZ
E 0123456789 . . . . . . . . . . -.- . ..- . . . . . . .-- . . . . . . .. . . . . .!
F 0123456789
ABcdeFGhijklmnopqrstuvwxYZ
ABcdefgHIjklmnopqrstuvwxYZ
ABcdefghiJKlmnopqrstuvwxYZ**********************************|
ABcdefghijkLMnopqrstuvwxYZ
ABcdefghijklmNOpqrstuvwxYZ------------......................|
ABcdefghijklmnoPQrstuvwxYZ
ABcdefghijklmnopqRStuvwxYZ..................................|
ABcdefghijklmnopqrsTUvwxYZ
ABcdefghijklmnopqrstuVWxYZ==================================|
ABcdefghijklmnopqrstuvwXYZ
ABcdefghijklmnopqrStUvwxyZ
ABcdefghijkLmnoPqrstuvwxyZ
ABcdEfghijKlmnopqrstuvwxyZ!@#$%^&*(){}[]<>qpbp..............|
abCdefghijklmnopqrstuvwxyZ
AbcdefghijklmnopqrstuvwxyZ
abcdefghijklmnopqrstuvwxyZ-abcdefghijklmnopqrstuvwxyZ-abcdefghijklmnopqrstuvwxyZ
*/
