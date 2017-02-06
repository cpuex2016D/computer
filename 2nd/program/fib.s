min_caml_start:
0	movi %r0, 10
1	jal fib
2	out %r0
3	j min_caml_start
fib:
4	bei %r0, 0, return_1
5	bei %r0, 1, return_1
6	sw %r0, 0(%r31)  # %r31はスタックポインタ
7	addi %r0, %r0, -1
8	addi %r31, %r31, 1
9	jal fib
10	sw %r0, 0(%r31)
11	lw %r0, -1(%r31)
12	addi %r0, %r0, -2
13	addi %r31, %r31, 1
14	jal fib
15	lw %r1, -1(%r31)
16	add %r0, %r0, %r1
17	addi %r31, %r31, -2
18	jr
return_1:
19	movi %r0, 1
20	jr
