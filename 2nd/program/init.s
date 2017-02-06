.section	".rodata"
.align	8
.section	".text"
.global min_caml_start
min_caml_start:
#レジスタ初期化
	movi	%r30, 0  #ヒープポインタ
	movi	%r31, 0x8000  #スタックポインタ
	sl2addi	%r31, %r31, 0
#データロード
data_load_loop:
	in	%r0
	sw	%r0, 0(%r30)
	addi	%r30, %r30, 1
	movi	%r0, 0
	j	data_load_loop
