#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main() {
	uint32_t word;

	printf("memory_initialization_radix=16;\nmemory_initialization_vector=");
	while (1) {
		int ret = fread(&word, 1, 4, stdin);
		switch (ret) {
		case 4:
			printf("\n%08x", word);
			break;
		case 0:
			if (feof(stdin)) {
				printf(";\n");
				return 0;
			}
		default:
			fprintf(stderr, "unexpected return value of fread: %d\n", ret);
			exit(1);
		}
	}
}
