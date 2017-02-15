.section	".rodata"
.align	8
.section	".text"
.global min_caml_start
min_caml_start:
entry_point:
#レジスタ初期化
	movi	%r31, 0  #ヒープポインタ
	movi	%r30, 0x7fff  #スタックポインタ
	sl2addi	%r30, %r30, 3
#データロード
data_load_loop:
	in	%r0
	sw	%r0, 0(%r31)
	addi	%r31, %r31, 1
	movi	%r0, 0
	j	data_load_loop
