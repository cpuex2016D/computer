`include "common.vh"

typedef enum logic {ADD, SUB, X_ADD_SUB=1'bx} add_or_sub_t;
typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	add_or_sub_t add_or_sub;
	logic sl2;
	cdb_t opd[1:0];
} add_sub_entry;



module add_sub #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t gpr_read[1:0],
	input cdb_t gpr_cdb,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	output cdb_t result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam add_sub_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		add_or_sub: X_ADD_SUB,
		sl2: 1'bx,
		opd: '{
			0: '{
				valid: 1'bx,
				tag: {ROB_WIDTH{1'bx}},
				data: 32'bx
			},
			1: '{
				valid: 1'bx,
				tag: {ROB_WIDTH{1'bx}},
				data: 32'bx
			}
		}
	};
	//add_sub_entry e[N_ENTRY-1:0] = '{default: e_invalid};  //この方法だと正しく初期化されない(vivadoのバグ?)
	add_sub_entry e[N_ENTRY-1:0];  //0から順に詰める
	add_sub_entry e_updated[N_ENTRY-1:0];
	add_sub_entry e_new;
	for (genvar j=0; j<N_ENTRY; j++) begin
		initial begin
			e[j] <= e_invalid;
		end
	end

	assign e_new.valid      = issue_req.valid;
	assign e_new.tag        = gpr_issue_tag;
	assign e_new.add_or_sub = inst.op[1] ? SUB : ADD;
	assign e_new.sl2        = inst.op[2];
	assign e_new.opd[0].valid = inst.op[0] ||
	                            (gpr_read[1].valid ? tag_match(gpr_cdb, e_new.opd[0].tag) ? 1'bx : 1
	                                               : tag_match(gpr_cdb, e_new.opd[0].tag) ?    1 : 0);  //オペランドが入れ替わるので注意
	assign e_new.opd[0].tag   = gpr_read[1].tag;
	assign e_new.opd[0].data  = inst.op[0] ? 32'($signed(inst.c_add_sub)) :
	                            (gpr_read[1].valid ? tag_match(gpr_cdb, e_new.opd[0].tag) ? 32'bx        : gpr_read[1].data
	                                               : tag_match(gpr_cdb, e_new.opd[0].tag) ? gpr_cdb.data : 32'bx);
	assign e_new.opd[1].valid = (gpr_read[0].valid ? tag_match(gpr_cdb, e_new.opd[1].tag) ? 1'bx : 1
	                                               : tag_match(gpr_cdb, e_new.opd[1].tag) ?    1 : 0);
	assign e_new.opd[1].tag   = gpr_read[0].tag;
	assign e_new.opd[1].data  = (gpr_read[0].valid ? tag_match(gpr_cdb, e_new.opd[1].tag) ? 32'bx        : gpr_read[0].data
	                                               : tag_match(gpr_cdb, e_new.opd[1].tag) ? gpr_cdb.data : 32'bx) << (e_new.sl2 ? 2 : 0);
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign e_updated[j].valid      = e[j].valid;
		assign e_updated[j].tag        = e[j].tag;
		assign e_updated[j].add_or_sub = e[j].add_or_sub;
		assign e_updated[j].sl2        = e[j].sl2;
		for (genvar k=0; k<2; k++) begin
			assign e_updated[j].opd[k].valid = e[j].opd[k].valid || tag_match(gpr_cdb, e[j].opd[k].tag);
			assign e_updated[j].opd[k].tag   = e[j].opd[k].tag;
		end
		assign e_updated[j].opd[0].data = e[j].opd[0].valid ? e[j].opd[0].data : gpr_cdb.data;
		assign e_updated[j].opd[1].data = e[j].opd[1].valid ? e[j].opd[1].data : gpr_cdb.data << (e[j].sl2 ? 2 : 0);
	end

	wire dispatched = e[0].opd[0].valid&&e[0].opd[1].valid ? 0 : 1;  //dispatchされるエントリの番号
	assign gpr_cdb_req.valid = e[0].valid&&e[0].opd[0].valid&&e[0].opd[1].valid ||
	                           e[1].valid&&e[1].opd[0].valid&&e[1].opd[1].valid;
	wire dispatch = gpr_cdb_req.valid && gpr_cdb_req.ready;
	assign issue_req.ready = dispatch || !e[N_ENTRY-1].valid;

	always_ff @(posedge clk) begin
		if (reset) begin
			e[0] <= e_invalid;
			e[1] <= e_invalid;
		end else begin
			if (dispatch) begin
				e[0] <= dispatched==0 ? e[1].valid ? e_updated[1] : e_new : e_updated[0];
				e[1] <= e[1].valid ? e_new : e_invalid;
			end else begin
				e[0] <= e[0].valid ? e_updated[0] : e_new;
				e[1] <= e[1].valid ? e_updated[1] : e[0].valid ? e_new : e_invalid;
			end
		end
		result.tag <= e[dispatched].tag;
		case (e[dispatched].add_or_sub)
			ADD: result.data <= e[dispatched].opd[0].data + e[dispatched].opd[1].data;
			SUB: result.data <= e[dispatched].opd[0].data - e[dispatched].opd[1].data;
		endcase
	end
endmodule
