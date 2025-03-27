#include "defs.h"

int main() {
	MatCalc m;

	mat_init_example(&m); 	// all 1s

	int status = mat_calc(&m);
	if (status == XST_SUCCESS) {
		// mat_print(m.mat_c);
		return 0;
	}
	xil_printf("Fail!\r\n");
	return 1;
}
