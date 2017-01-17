#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main(){
	enum mode_t {
		NORMAL,
		COMMENT,
	} mode;
	int c;
	uint32_t bits = 0;
	int i = 0;
	int line = 1;

	while ((c = getchar()) != EOF) {
		if (mode == NORMAL) {
			switch (c) {
			case '0':
				if (i == 32) { fprintf(stderr, "error: line %d: more than 32 digits\n", line); exit(1); }
				i++;
				break;
			case '1':
				if (i == 32) { fprintf(stderr, "error: line %d: more than 32 digits\n", line); exit(1); }
				bits |= 1 << (31-i);
				i++;
				break;
			case '#':
				mode = COMMENT;
				break;
			}
		}
		if (c == '\n') {
			if (i != 0) {
				if (i != 32) { fprintf(stderr, "error: line %d: less than 32 digits\n", line); exit(1); }
				if (fwrite(&bits, 4, 1, stdout) != 1) { perror("fwrite"); exit(1); }
				bits = i = 0;
			}
			mode = NORMAL;
			line++;
		}
	}

	return 0;
}
