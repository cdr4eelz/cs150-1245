#define RECV_CTRL (*((volatile unsigned int*)0x80000004) & 0x01)
#define RECV_DATA (*((volatile unsigned int*)0x8000000C) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

int main(void)
{
    for ( ; ; )
    {
        while (!RECV_CTRL) ;
        char byte = RECV_DATA;
        while (!TRAN_CTRL) ;
        TRAN_DATA = byte;
    }

    return 0;
}

/*
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


#define D2M_SIZE    (12 * 1024)
#define M2D_SIZE    ( 4 * 1024)
__attribute__ ((aligned))
u8 D2M_BUF[D2M_SIZE];
__attribute__ ((aligned))
u8 M2D_BUF[M2D_SIZE];

    u8 *pD2M_H = D2M_BUF, *pD2M_T = D2M_BUF, *pD2M_W = (D2M_BUF + D2M_SIZE);
    u8 *pM2D_H = M2D_BUF, *pM2D_T = M2D_BUF, *pM2D_W = (M2D_BUF + M2D_SIZE);

    u32 tally_D2M_Rx=0, tally_M2D_Rx=0, tally_D2M_Tx=0, tally_M2D_Tx=0;
    while (1) { //(tally_D2M_Tx < (2*1024)) {
        tally_D2M_Rx += RxIntoBuf(D2M_BUF, pD2M_W, &pD2M_H, pD2M_T, U_DEBUG, FALSE, 9);
        tally_D2M_Tx += TxFromBuf(D2M_BUF, pD2M_W, pD2M_H, &pD2M_T, U_MIPSY, TRUE , 5);
        tally_M2D_Rx += RxIntoBuf(M2D_BUF, pM2D_W, &pM2D_H, pM2D_T, U_MIPSY, FALSE, 3);
        tally_M2D_Tx += TxFromBuf(M2D_BUF, pM2D_W, pM2D_H, &pM2D_T, U_DEBUG, FALSE, 2);
    }
*/
