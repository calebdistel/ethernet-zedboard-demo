/*
 * Minimal Zynq-7000 platform layer for a polled lwIP RAW/UDP application.
 *
 * SDT flow (Vitis Unified 2024.1): the lwIP GEM adapter configures the GIC
 * and registers its own interrupt through XSetupInterruptSystem(), so all the
 * platform has to do is unmask IRQs on the CPU. No lwIP TCP timers are needed
 * because the application only uses UDP and drives ARP explicitly.
 */
#include "xil_cache.h"
#include "xil_exception.h"
#include "platform.h"

#ifndef SDT
#include "xparameters.h"
#include "xscugic.h"
static XScuGic Gic;
#endif

void init_platform(void)
{
    Xil_ICacheEnable();
    Xil_DCacheEnable();

#ifndef SDT
    /* Classic (non-SDT) BSP: the adapter registers with the GIC by base
     * address, so the GIC and the CPU exception vector must be set up here. */
    XScuGic_Config *cfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    XScuGic_CfgInitialize(&Gic, cfg, cfg->CpuBaseAddress);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler, &Gic);
#endif
}

void platform_enable_interrupts(void)
{
    Xil_ExceptionEnable();
}

void cleanup_platform(void)
{
    Xil_DCacheDisable();
    Xil_ICacheDisable();
}
