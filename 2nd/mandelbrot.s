.section	".rodata"
.align	8
l0.0:	! 0.000000
	0x0
l400.0:	! 400.000000
	0x43c80000
l1.5:	! 1.500000
	0x3fc00000
l1.0:	! 1.000000
	0x3f800000
l4.0:	! 4.000000
	0x40800000
.section	".text"
.global	min_caml_start
min_caml_start:
	flwi	%f31, l0.0
	flwi	%f30, l400.0
	flwi	%f29, l1.5
	flwi	%f28, l1.0
	flwi	%f27, l4.0
	movi	%r0, 0
	jal	yloop
	in	%r0
	j	min_caml_start
iloop:
	bei	%r0, 0, iloop_print1
	fsub	%f2, %f2, %f3
	fadd	%f0, %f0, %f0
	fmul	%f1, %f0, %f1
	fadd	%f0, %f2, %f4
	fadd	%f1, %f1, %f5
	fmul	%f2, %f0, %f0
	fmul	%f3, %f1, %f1
	fadd	%f6, %f2, %f3
	fble	%f6, %f27, iloop_next
	movi	%r0, 0
	out	%r0
	jr
iloop_print1:
	movi	%r0, 1
	out	%r0
return:
	jr
iloop_next:
	addi	%r0, %r0, -1
	j	iloop
xloop:
	movi	%r2, 400
	ble	%r2, %r0, return
	itof	%f0, %r0
	itof	%f1, %r1
	fadd	%f0, %f0, %f0
	fadd	%f1, %f1, %f1
	fdiv	%f0, %f0, %f30
	fdiv	%f1, %f1, %f30
	fsub	%f4, %f0, %f29
	fsub	%f5, %f1, %f28
	fmov	%f0, %f31
	fmov	%f1, %f31
	fmov	%f2, %f31
	fmov	%f3, %f31
	sw	%r0, 0(%r31)
	sw	%r1, 1(%r31)
	movi	%r0, 1000
	addi	%r31, %r31, 2
	jal	iloop
	addi	%r31, %r31, -2
	lw	%r0, 0(%r31)
	lw	%r1, 1(%r31)
	addi	%r0, %r0, 1
	j	xloop
yloop:
	movi	%r1, 400
	ble	%r1, %r0, return
	sw	%r0, 0(%r31)
	mov	%r1, %r0
	movi	%r0, 0
	addi	%r31, %r31, 1
	jal	xloop
	addi	%r31, %r31, -1
	lw	%r0, 0(%r31)
	addi	%r0, %r0, 1
	j	yloop
