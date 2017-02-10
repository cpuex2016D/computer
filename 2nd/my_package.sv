package my_package;
	parameter IN_BUFFER_WIDTH = 9;  //4バイト単位
	parameter OUT_BUFFER_WIDTH = 9;  //1バイト単位
	parameter INST_WIDTH = 32;
	parameter INST_MEM_WIDTH = 14;
	parameter DATA_MEM_WIDTH = 17;
	parameter REG_WIDTH = 5;
	parameter ROB_WIDTH = 4;  // ROB_WIDTH >= COMMIT_RING_WIDTH
	parameter COMMIT_RING_WIDTH = 4;  //commit_ring.in_countのみparameterizeされていない
	parameter PATTERN_WIDTH = INST_MEM_WIDTH;
	parameter GH_WIDTH = 10;
	parameter ADDR_STACK_WIDTH = 4;
	parameter GC_WIDTH = 8;
	parameter GD_WIDTH = 2;

	parameter N_B_ENTRY = 4;
	parameter N_ACC = 3;  //core.inst_mem_stall, register_file.acc_all_valid_parallel, register_file.no_acc_reqのみparameterizeされていない
	parameter N_CORE = 4;  //register_file, topのみparameterizeされていない

	parameter PC_INIT = 0;

	typedef struct {  //packedでないとfunctionの引数にできない? -> packageの中に入れたらエラーが出なくなった
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		logic[31:0] data;
	} cdb_t;

	function logic tag_match(cdb_t cdb, logic[ROB_WIDTH-1:0] tag);
		return cdb.valid && cdb.tag==tag;
	endfunction

	typedef struct {  //packedでないと "arrays have different elements" というエラーが出る -> packageの中に入れたらエラーが出なくなった
		logic valid;
		logic[REG_WIDTH-1:0] arch_num;
		logic[31:0] data;
	} rob_entry;

	typedef enum logic[2:0] {
		 COMMIT_GPR,
		 COMMIT_FPR,
		 COMMIT_GPR_IN,
		 COMMIT_FPR_IN,
		 COMMIT_B,
		 COMMIT_NULL = 3'b11x,
		 COMMIT_X = 3'bx
	} commit_ring_entry;

	typedef enum logic {LOAD, EXEC} mode_t;
endpackage
