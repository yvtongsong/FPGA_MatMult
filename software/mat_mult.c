#include "defs.h"

u32 *mat_get_block(u32 *mat, int blk_row, int blk_col) {
	return mat + BLOCK_SIZE * BLOCK_SIZE * (blk_row * MATRIX_BLOCK_SIZE + blk_col);
}

int mat_calc(MatCalc *m) {
	init_hw(&m->AxiDma);

	XTime start, end;
	XTime_GetTime(&start);
	int status = XST_SUCCESS;
	for (int i = 0; i < MATRIX_BLOCK_SIZE; i++) {
		for (int j = 0; j < MATRIX_BLOCK_SIZE; j++) {
			for (int k = 0; k < MATRIX_BLOCK_SIZE; k++) {
				u32 *tx_buf_a = mat_get_block(m->mat_a, i, k);
				u32 *tx_buf_b = mat_get_block(m->mat_b, k, j);
				u32 *rx_buf_c = mat_get_block(m->mat_c, i, j);
				status = dma_transfer(&m->AxiDma, tx_buf_a, tx_buf_b, m->blk_tmp);
				for (int p = 0; p < BLOCK_SIZE*BLOCK_SIZE; p++) {
					rx_buf_c[p] += m->blk_tmp[p];
				}
				if (status != XST_SUCCESS) {
					return status;
				}
			}
		}
	}
	XTime_GetTime(&end);
	double elapsed_seconds = (double)(end - start) / XPAR_CPU_TIMESTAMP_CLK_FREQ;
	printf("Elapsed time: %.6f seconds\n", elapsed_seconds);

	return status;
}

void mat_init_example(MatCalc *m) {
	m->mat_a = (u32 *)DDR_HIGH_ADDR;
	m->mat_b = (u32 *)(m->mat_a + MATRIX_SIZE*MATRIX_SIZE*sizeof(u32));
	m->mat_c = (u32 *)(m->mat_b + MATRIX_SIZE*MATRIX_SIZE*sizeof(u32));
	m->blk_tmp = (u32 *)(m->mat_c + BLOCK_SIZE*BLOCK_SIZE*sizeof(u32));
	for (int i = 0; i < MATRIX_SIZE*MATRIX_SIZE; i++) {
		m->mat_a[i] = 1;
		m->mat_b[i] = 1;
		m->mat_c[i] = 0;
	}
}

u32 mat_get(u32 *mat, int i, int j) {
	int blk_row = i / BLOCK_SIZE;
	int blk_col = j / BLOCK_SIZE;
	u32 *blk = mat_get_block(mat, blk_row, blk_col);

	int row = i % BLOCK_SIZE;
	int col = j % BLOCK_SIZE;

	return blk[row*BLOCK_SIZE + col];
}

void mat_put(u32 *mat, int i, int j, u32 value) {
	int blk_row = i / BLOCK_SIZE;
	int blk_col = j / BLOCK_SIZE;
	u32 *blk = mat_get_block(mat, blk_row, blk_col);

	int row = i % BLOCK_SIZE;
	int col = j % BLOCK_SIZE;

	blk[row*BLOCK_SIZE + col] = value;
}

void mat_print(u32 *mat) {
	//for (int i = 0; i < MATRIX_BLOCK_SIZE; i++) {
	//	printf("[");
	//	// get i-th blk_row
	//	for (int j = 0; j < BLOCK_SIZE; j++) {
	//			// get j-th row of i-th row blocks
	//		for (int k = 0; k < MATRIX_BLOCK_SIZE; k++) {
	//			// get (i, k) block
	//			for (int m = 0; m < BLOCK_SIZE; m++) {
	//				// block(i, k), blk_row = j, blk_col = m
	//				printf(" %8x", mat_get_block(mat, i, k)[j*BLOCK_SIZE + m]);
	//			}
	//		}
	//	}
	//	printf("]\r\n");
	//}
	for (int i = 0; i < MATRIX_SIZE; i++) {
		printf("[");
		for (int j = 0; j <MATRIX_SIZE; j++) {
			printf(" %8x", mat_get(mat, i, j));
		}
		printf("]\r\n");
	}
}
