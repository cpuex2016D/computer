`include "common.vh"

interface cdb_if #(
	parameter DATA_WIDTH = 32
);
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic[DATA_WIDTH-1:0] data;
	function logic tag_match(logic[ROB_WIDTH-1:0] _tag);
		return valid && tag==_tag;
	endfunction
endinterface

interface inst_if;
	logic[INST_WIDTH-1:0] bits;
	wire[5:0] op = bits[31:26];
	wire[4:0] r0 = bits[25:21];
	wire[4:0] r1 = bits[20:16];
	wire[4:0] r2 = bits[15:11];
	wire[15:0] c = bits[15:0];
endinterface

interface req_if;
	logic valid;
	logic ready;
endinterface

interface unit_if;
	inst_if inst();
	cdb_t read[1:0];
	logic[ROB_WIDTH-1:0] new_tag;
	cdb_t cdb;
	struct {
		logic stall;
	} feedback;
	req_if req();
	cdb_t result;
endinterface
