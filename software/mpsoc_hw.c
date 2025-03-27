#include "defs.h"

int init_hw(XAxiDma *AxiDma) {
	int status;

	XAxiDma_Config *CfgPtr;
	CfgPtr = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
	if (!CfgPtr) {
		xil_printf("No config found for %d\r\n", XPAR_XAXIDMA_0_BASEADDR);
		return XST_FAILURE;
	}

	status = XAxiDma_CfgInitialize(AxiDma, CfgPtr);
	if (status != XST_SUCCESS) {
		xil_printf("Initialization failed %d\r\n", status);
		return XST_FAILURE;
	}

	if (XAxiDma_HasSg(AxiDma)) {
		xil_printf("Device configured as SG mode \r\n");
		return XST_FAILURE;
	}

	XAxiDma_IntrDisable(AxiDma, XAXIDMA_IRQ_ALL_MASK,
			    XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrDisable(AxiDma, XAXIDMA_IRQ_ALL_MASK,
			    XAXIDMA_DMA_TO_DEVICE);

	return XST_SUCCESS;
}

int wait_dma_reset(XAxiDma *AxiDma) {
	int time_out = POLL_TIMEOUT_COUNTER;
	XAxiDma_Reset(AxiDma);
	while (1) {
		if (XAxiDma_ResetIsDone(AxiDma)) {
			return XST_SUCCESS;
		}
		time_out--;
		usleep(1u);
	}
	return XST_FAILURE;
}

int wait_dma_idle(XAxiDma *AxiDma, u8 direction) {
	int time_out = POLL_TIMEOUT_COUNTER;
	while (1) {
		if (!XAxiDma_Busy(AxiDma, direction)) {
			return XST_SUCCESS;
		}
		time_out--;
		usleep(1u);
	}
	return XST_FAILURE;
}

int dma_transfer(XAxiDma *AxiDma, u32 *tx_buf_a, u32 *tx_buf_b, u32 *rx_buf_c) {
	Xil_DCacheFlushRange((UINTPTR)tx_buf_a, BLOCK_SIZE*BLOCK_SIZE*sizeof(u32));
	Xil_DCacheFlushRange((UINTPTR)tx_buf_b, BLOCK_SIZE*BLOCK_SIZE*sizeof(u32));
	Xil_DCacheFlushRange((UINTPTR)rx_buf_c, BLOCK_SIZE*BLOCK_SIZE*sizeof(u32));

	int status = XST_SUCCESS;

	// send matrix_a
	// status = wait_dma_reset(AxiDma);
	status = wait_dma_idle(AxiDma, XAXIDMA_DMA_TO_DEVICE);
	status = XAxiDma_SimpleTransfer(AxiDma, (UINTPTR) tx_buf_a,
			BLOCK_SIZE*BLOCK_SIZE*sizeof(u32), XAXIDMA_DMA_TO_DEVICE);

	// send matrix_b
	status = wait_dma_idle(AxiDma, XAXIDMA_DMA_TO_DEVICE);
	status = XAxiDma_SimpleTransfer(AxiDma, (UINTPTR) tx_buf_b,
			BLOCK_SIZE*BLOCK_SIZE*sizeof(u32), XAXIDMA_DMA_TO_DEVICE);

	// receive matrix_c
	status = wait_dma_idle(AxiDma, XAXIDMA_DEVICE_TO_DMA);
	status = XAxiDma_SimpleTransfer(AxiDma, (UINTPTR) rx_buf_c,
			BLOCK_SIZE*BLOCK_SIZE*sizeof(u32), XAXIDMA_DEVICE_TO_DMA);

	return status;
}
