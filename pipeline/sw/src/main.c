/*
 * ethernet_udp_app - ZedBoard FFT frames over Ethernet
 *
 *   SignalCha_ip (NCO -> FFT -> |Mag|) -> AXIS FIFO -> AXI DMA (S2MM) -> DDR -> lwIP -> UDP -> PC
 *
 * The signal chain runs continuously. For each frame the DMA copies the next
 * 1024 samples into DDR, then the frame is sent as 4 UDP packets.
 *
 * Build with -DZED_EMULATION for QEMU: QEMU has no FPGA, so capture_frame()
 * copies the frames from golden_frame.h (IP core RTL simulation) instead.
 *
 * Network: ZedBoard 192.168.50.2:5000  ->  PC 192.168.50.1:PC_PORT
 * Packet : 12-byte header (frame, packet, packets per frame, start bin, bin count, 0)
 *          as little-endian u16, then 256 bins as little-endian u32
 */

#include <string.h>

#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xil_io.h"
#ifdef SDT
#include "xiltimer.h"
#else
#include "xtime_l.h"
#endif

#include "lwip/init.h"
#include "lwip/udp.h"
#include "lwip/etharp.h"
#include "lwip/inet.h"
#include "netif/xadapter.h"

#include "platform.h"

#ifdef ZED_EMULATION
#include "golden_frame.h"
#endif

/* ---------------------------------------------------------------- config */
#define NUM_FRAMES       3
#define FFT_BINS         1024
#define BINS_PER_PACKET  256
#define PACKETS          (FFT_BINS / BINS_PER_PACKET)
#define HEADER_BYTES     12

#define ZED_IP   "192.168.50.2"
#define PC_IP    "192.168.50.1"
#define ZED_PORT 5000
#ifndef PC_PORT
#define PC_PORT  5001
#endif

/* AXI DMA, simple mode, S2MM (stream -> DDR) registers */
#define DMA_BASE     XPAR_AXI_DMA_0_BASEADDR
#define S2MM_DMACR   0x30          /* control: bit0 run, bit2 reset */
#define S2MM_DMASR   0x34          /* status:  bit1 idle            */
#define S2MM_DA      0x48          /* destination address           */
#define S2MM_LENGTH  0x58          /* bytes; writing it starts a transfer */

/* HDL Coder IP core registers (SignalCha_ip_addr.h) */
#define IP_BASE        XPAR_SIGNALCHA_IP_0_BASEADDR
#define IP_RESET       0x000       /* write 1: reset NCO, FFT, FIFO, TLAST counter */
#define IP_PACKET_SIZE 0x008       /* TLAST every N samples         */
#define IP_CHAIN_EN    0x100       /* 1 = signal chain running      */

/* ----------------------------------------------------------------- state */
static u32 RxBuffer[FFT_BINS] __attribute__((aligned(64)));
static u8  Packet[HEADER_BYTES + BINS_PER_PACKET * 4];

static struct netif Netif;
static struct udp_pcb *Pcb;
static ip_addr_t PcAddr;

/* ---------------------------------------------------------------- timing */
static u64 now_us(void)
{
    XTime t;
    XTime_GetTime(&t);
    return (u64)t / (COUNTS_PER_SECOND / 1000000U);
}

/* Let lwIP handle received packets (ARP replies) for a while */
static void poll_net(u32 ms)
{
    u64 end = now_us() + (u64)ms * 1000U;
    while (now_us() < end)
        xemacif_input(&Netif);
}

/* -------------------------------------------------------- frame capture */
#ifndef ZED_EMULATION
/* Once: reset the DMA and the IP core, then start the signal chain. It keeps
 * running; while the DMA is not armed, the IP core pauses the chain instead of
 * dropping samples, so each DMA transfer is the next frame of one stream. */
static void pl_start(void)
{
    Xil_Out32(DMA_BASE + S2MM_DMACR, 0x4);                   /* reset DMA          */
    while (Xil_In32(DMA_BASE + S2MM_DMACR) & 0x4)
        ;
    Xil_Out32(DMA_BASE + S2MM_DMACR, 0x1);                   /* run                */

    Xil_Out32(IP_BASE + IP_RESET, 1);                        /* reset IP core      */
    Xil_Out32(IP_BASE + IP_PACKET_SIZE, FFT_BINS);           /* TLAST every frame  */
    Xil_Out32(IP_BASE + IP_CHAIN_EN, 1);                     /* start signal chain */
}

/* DMA the next frame into RxBuffer */
static int capture_frame(void)
{
    Xil_DCacheFlushRange((UINTPTR)RxBuffer, sizeof(RxBuffer));
    Xil_Out32(DMA_BASE + S2MM_DA, (u32)(UINTPTR)RxBuffer);
    Xil_Out32(DMA_BASE + S2MM_LENGTH, sizeof(RxBuffer));     /* start transfer     */

    u64 deadline = now_us() + 100000;                        /* 100 ms             */
    while (!(Xil_In32(DMA_BASE + S2MM_DMASR) & 0x2)) {       /* wait for idle      */
        if (now_us() > deadline)
            return -1;
    }
    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, sizeof(RxBuffer));   /* read DDR, not cache */
    return 0;
}
#else
static void pl_start(void) { }

/* Virtual FPGA: the frames the DMA would have written, in order */
static int capture_frame(void)
{
    static int next = 0;
    memcpy(RxBuffer, GoldenFrames[next % GOLDEN_FRAMES], sizeof(RxBuffer));
    next++;
    return 0;
}
#endif

/* --------------------------------------------------------------- network */
static void put16(u8 *p, u16 v) { p[0] = (u8)v; p[1] = (u8)(v >> 8); }

static void send_bytes(const void *data, u16 len)
{
    struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, len, PBUF_RAM);
    if (!p)
        return;
    memcpy(p->payload, data, len);
    udp_sendto(Pcb, p, &PcAddr, PC_PORT);
    pbuf_free(p);
}

static int net_init(void)
{
    ip_addr_t ip, mask, gw;
    unsigned char mac[6] = {0x02, 0x00, 0x00, 0x00, 0x00, 0x02};

    inet_aton(ZED_IP, &ip);
    inet_aton("255.255.255.0", &mask);
    ip_addr_set_zero(&gw);
    inet_aton(PC_IP, &PcAddr);

    lwip_init();
    if (!xemac_add(&Netif, &ip, &mask, &gw, mac, XPAR_XEMACPS_0_BASEADDR))
        return -1;
    netif_set_default(&Netif);
    platform_enable_interrupts();
    netif_set_up(&Netif);

    Pcb = udp_new();
    if (!Pcb || udp_bind(Pcb, IP_ADDR_ANY, ZED_PORT) != ERR_OK)
        return -1;

    /* Find the PC's MAC address (ARP) before sending frames: lwIP holds only
     * one packet while ARP is pending, so a frame sent now would lose packets.
     * A 1-byte packet triggers ARP; the receiver ignores it. */
    struct eth_addr *eth;
    const ip4_addr_t *found;
    u8 ping = 0;
    for (int i = 0; i < 20; i++) {
        send_bytes(&ping, 1);
        poll_net(250);
        if (etharp_find_addr(&Netif, ip_2_ip4(&PcAddr), &eth, &found) >= 0)
            return 0;
    }
    return -1;
}

/* Send RxBuffer as 4 packets of 256 bins */
static void send_frame(u16 frame)
{
    for (u16 pkt = 0; pkt < PACKETS; pkt++) {
        u16 start = pkt * BINS_PER_PACKET;
        put16(&Packet[0], frame);
        put16(&Packet[2], pkt);
        put16(&Packet[4], PACKETS);
        put16(&Packet[6], start);
        put16(&Packet[8], BINS_PER_PACKET);
        put16(&Packet[10], 0);
        for (u32 i = 0; i < BINS_PER_PACKET; i++) {
            u32 v = RxBuffer[start + i];
            u8 *d = &Packet[HEADER_BYTES + 4 * i];
            d[0] = (u8)v; d[1] = (u8)(v >> 8); d[2] = (u8)(v >> 16); d[3] = (u8)(v >> 24);
        }
        send_bytes(Packet, sizeof(Packet));
        poll_net(2);
    }
}

/* ------------------------------------------------------------------ main */
int main(void)
{
    init_platform();
    xil_printf("\r\nZedBoard FFT -> UDP %s:%d\r\n", PC_IP, PC_PORT);

    if (net_init() != 0) {
        xil_printf("ERROR: network setup failed (cable, PC address %s?)\r\n", PC_IP);
        goto idle;
    }
    xil_printf("Network up\r\n");

    pl_start();
    for (u16 f = 1; f <= NUM_FRAMES; f++) {
        if (capture_frame() != 0) {
            xil_printf("ERROR: DMA timeout on frame %d\r\n", f);
            break;
        }
        send_frame(f);
        xil_printf("Frame %d sent\r\n", f);
    }
    xil_printf("Done\r\n");

idle:
    while (1)                       /* keep answering ARP */
        xemacif_input(&Netif);

    cleanup_platform();
    return 0;
}
