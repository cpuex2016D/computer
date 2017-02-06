#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main() {
	uint32_t word;

	while (1) {
		int ret = fread(&word, 1, 4, stdin);
		switch (ret) {
		case 4:
			printf("%08x\n", word);
			break;
		case 0:
			if (feof(stdin)) {
				return 0;
			}
		default:
			fprintf(stderr, "unexpected return value of fread: %d\n", ret);
			exit(1);
		}
	}
}
