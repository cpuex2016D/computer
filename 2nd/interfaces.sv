`include "common.vh"

interface inst_if;
	logic[INST_WIDTH-1:0] bits;
	wire[5:0] op = bits[31:26];
	wire[4:0] r0 = bits[25:21];
	wire[4:0] r1 = bits[20:16];
	wire[4:0] r2 = bits[15:11];
	wire[15:0] c_add_sub = bits[15:0];
	wire[15:0] c_lw      = bits[15:0];
	wire[17:0] c_lwi     = bits[17:0];
	wire[15:0] c_sw      = {bits[25:21], bits[10:0]};
	wire[17:0] c_swi     = {bits[17:16], bits[25:21], bits[10:0]};
	wire[13:0] c_j       = {bits[23:21], bits[10:0]};
	wire[8:0] c_cmp      = {bits[27:24], bits[15:11]};
	wire is_add_sub = op[5:3]==3'b000 && op[2:1]!=2'b11;
	wire is_lw_sw   = op[5:3]==3'b010;
	wire is_in      = op==6'b011010;
	wire is_out     = op==6'b011100;
	wire is_j       = op[5:3]==3'b100;
	wire is_b       = op[5]==1'b1 && op[4:3]!=2'b00;
endinterface

interface req_if;
	logic valid;
	logic ready;
endinterface

//TODO delete
interface unit_if;
	inst_if inst();
	cdb_t read[1:0];
	logic[ROB_WIDTH-1:0] issue_tag;
	cdb_t cdb;
	req_if issue_req();
	req_if cdb_req();
	req_if commit_req();
	struct {
		logic[ROB_WIDTH-1:0] tag;
		logic[31:0] data;
	} result;
endinterface
