.section	".rodata"
.align	8
.section	".text"
.global	min_caml_start
min_caml_start:
entry_point:
	movi	%r0, 10
	jal	fib
	out	%r0
	j	min_caml_start
fib:
	bei	%r0, 0, return_1
	bei	%r0, 1, return_1
	sw	%r0, 0(%r31)  # %r31はスタックポインタ
	addi	%r0, %r0, -1
	addi	%r31, %r31, 1
	jal	fib
	sw	%r0, 0(%r31)
	lw	%r0, -1(%r31)
	addi	%r0, %r0, -2
	addi	%r31, %r31, 1
	jal	fib
	lw	%r1, -1(%r31)
	add	%r0, %r0, %r1
	addi	%r31, %r31, -2
	jr
return_1:
	movi	%r0, 1
	jr
