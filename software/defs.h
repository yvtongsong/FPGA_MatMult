#define MATRIX_SIZE 1024
#define BLOCK_SIZE 	8
#define MATRIX_BLOCK_SIZE MATRIX_SIZE/BLOCK_SIZE
#define POLL_TIMEOUT_COUNTER 1000000U
#define DDR_HIGH_ADDR 0x0801000000

#include "xaxidma.h"
#include "xparameters.h"
#include "sleep.h"
#include "xiltimer.h"
#include "xstatus.h"
#include "xil_types.h"
#include <stdio.h>

// mat_mult
typedef struct {
	u32 *mat_a;
	u32 *mat_b;
	u32 *mat_c;
	u32 *blk_tmp;
	XAxiDma AxiDma;
} MatCalc;

u32 *mat_get_block(u32 *mat, int blk_row, int blk_col);
int mat_calc(MatCalc *m);
void mat_init_example(MatCalc *m);
u32 mat_get(u32 *mat, int i, int j);
void mat_put(u32 *mut, int i, int j, u32 value);
void mat_print(u32 *mat);

// mpsoc_hw
int init_hw(XAxiDma *AxiDma);
int wait_dma_reset(XAxiDma *AxiDma);
int wait_dma_idle(XAxiDma *AxiDma, u8 direction);
int dma_transfer(XAxiDma *AxiDma, u32 *tx_buf_a, u32 *tx_buf_b, u32 *rx_buf_c);
