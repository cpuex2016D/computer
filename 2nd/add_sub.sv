`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	enum logic {ADD, SUB, X_ADD_SUB=1'bx} add_or_sub;
	logic sl2;
	cdb_t opd[1:0];
} add_sub_entry;



module add_sub #(
) (
	input logic clk,
	inst_if inst,
	cdb_t gpr_read[1:0],
	cdb_t gpr_cdb,
	logic[ROB_WIDTH-1:0] gpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	cdb_t result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam add_sub_entry entry_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		add_or_sub: X_ADD_SUB,
		sl2: 1'bx,
		opd: '{default: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}}
	};
	//add_sub_entry entry[N_ENTRY-1:0] = '{default: entry_invalid};  //この方法だと正しく初期化されない(vivadoのバグ?)
	add_sub_entry entry[N_ENTRY-1:0];  //0から順に詰める
	add_sub_entry entry_updated[N_ENTRY-1:0];
	add_sub_entry entry_new;
	for (genvar j=0; j<N_ENTRY; j++) begin
		initial begin
			entry[j] <= entry_invalid;
		end
	end

	assign entry_new.valid      = issue_req.valid;
	assign entry_new.tag        = gpr_issue_tag;
	assign entry_new.add_or_sub = inst.op[1] ? SUB : ADD;
	assign entry_new.sl2        = inst.op[2];
	assign entry_new.opd[0].valid = inst.op[0] ||
	                                (gpr_read[1].valid ? tag_match(gpr_cdb, entry_new.opd[0].tag) ? 1'bx : 1
	                                                   : tag_match(gpr_cdb, entry_new.opd[0].tag) ?    1 : 0);  //オペランドが入れ替わるので注意
	assign entry_new.opd[0].tag   = gpr_read[1].tag;
	assign entry_new.opd[0].data  = inst.op[0] ? 32'($signed(inst.c_add_sub)) :
	                                (gpr_read[1].valid ? tag_match(gpr_cdb, entry_new.opd[0].tag) ? 32'bx        : gpr_read[1].data
	                                                   : tag_match(gpr_cdb, entry_new.opd[0].tag) ? gpr_cdb.data : 32'bx);
	assign entry_new.opd[1].valid = (gpr_read[0].valid ? tag_match(gpr_cdb, entry_new.opd[1].tag) ? 1'bx : 1
	                                                   : tag_match(gpr_cdb, entry_new.opd[1].tag) ?    1 : 0);
	assign entry_new.opd[1].tag   = gpr_read[0].tag;
	assign entry_new.opd[1].data  = (gpr_read[0].valid ? tag_match(gpr_cdb, entry_new.opd[1].tag) ? 32'bx        : gpr_read[0].data
	                                                   : tag_match(gpr_cdb, entry_new.opd[1].tag) ? gpr_cdb.data : 32'bx) << (entry_new.sl2 ? 2 : 0);
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign entry_updated[j].valid      = entry[j].valid;
		assign entry_updated[j].tag        = entry[j].tag;
		assign entry_updated[j].add_or_sub = entry[j].add_or_sub;
		assign entry_updated[j].sl2        = entry[j].sl2;
		for (genvar k=0; k<2; k++) begin
			assign entry_updated[j].opd[k].valid = entry[j].opd[k].valid || tag_match(gpr_cdb, entry[j].opd[k].tag);
			assign entry_updated[j].opd[k].tag   = entry[j].opd[k].tag;
		end
		assign entry_updated[j].opd[0].data = entry[j].opd[0].valid ? entry[j].opd[0].data : gpr_cdb.data;
		assign entry_updated[j].opd[1].data = entry[j].opd[1].valid ? entry[j].opd[1].data : gpr_cdb.data << (entry[j].sl2 ? 2 : 0);
	end

	wire dispatched = entry[0].opd[0].valid&&entry[0].opd[1].valid ? 0 : 1;  //dispatchされるエントリの番号
	assign gpr_cdb_req.valid = entry[0].valid&&entry[0].opd[0].valid&&entry[0].opd[1].valid ||
	                           entry[1].valid&&entry[1].opd[0].valid&&entry[1].opd[1].valid;
	wire dispatch = gpr_cdb_req.valid && gpr_cdb_req.ready;
	assign issue_req.ready = dispatch || !entry[N_ENTRY-1].valid;

	always_ff @(posedge clk) begin
		if (reset) begin
			entry[0] <= entry_invalid;
			entry[1] <= entry_invalid;
		end else begin
			if (dispatch) begin
				entry[0] <= dispatched==0 ? entry[1].valid ? entry_updated[1] : entry_new : entry_updated[0];
				entry[1] <= entry[1].valid ? entry_new : entry_invalid;
			end else begin
				entry[0] <= entry[0].valid ? entry_updated[0] : entry_new;
				entry[1] <= entry[1].valid ? entry_updated[1] : entry[0].valid ? entry_new : entry_invalid;
			end
		end
		result.tag <= entry[dispatched].tag;
		case (entry[dispatched].add_or_sub)
			ADD: result.data <= entry[dispatched].opd[0].data + entry[dispatched].opd[1].data;
			SUB: result.data <= entry[dispatched].opd[0].data - entry[dispatched].opd[1].data;
		endcase
	end
endmodule
