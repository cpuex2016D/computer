parameter INST_WIDTH = 32;
parameter REG_WIDTH = 5;
parameter ROB_WIDTH = 4;

typedef struct packed {  //packedでないとfunctionの引数にできない?
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic[31:0] data;
} cdb_t;

function logic tag_match(cdb_t cdb, logic[ROB_WIDTH-1:0] tag);
	return cdb.valid && cdb.tag==tag;
endfunction
