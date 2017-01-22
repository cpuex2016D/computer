`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic is_fneg;
	logic is_fabs;
	cdb_t opd;
} fmov_entry;
function logic[31:0] modify_sign(logic is_fneg, logic is_fabs, logic[31:0] data);
	logic sign = is_fabs ? is_fneg ? 1'bx      : 0
	                     : is_fneg ? !data[31] : data[31];
	return {sign, data[30:0]};
endfunction

module fmov #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t fpr_read[1:0],
	input cdb_t fpr_cdb,
	input logic[ROB_WIDTH-1:0] fpr_issue_tag,
	req_if issue_req,
	req_if fpr_cdb_req,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam fmov_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		is_fneg: 1'bx,
		is_fabs: 1'bx,
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}
	};
	fmov_entry e[N_ENTRY-1:0];  //0から順に詰める
	fmov_entry e_updated[N_ENTRY-1:0];
	fmov_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid     = issue_req.valid;
	assign e_new.tag       = fpr_issue_tag;
	assign e_new.is_fneg   = inst.op[0];
	assign e_new.is_fabs   = inst.op[1];
	assign e_new.opd.valid = fpr_read[0].valid ? tag_match(fpr_cdb, e_new.opd.tag) ? 1'bx : 1
	                                           : tag_match(fpr_cdb, e_new.opd.tag) ?    1 : 0;
	assign e_new.opd.tag   = fpr_read[0].tag;
	assign e_new.opd.data  = modify_sign(e_new.is_fneg, e_new.is_fabs,
	                           fpr_read[0].valid ? tag_match(fpr_cdb, e_new.opd.tag) ? 32'bx        : fpr_read[0].data
	                                             : tag_match(fpr_cdb, e_new.opd.tag) ? fpr_cdb.data : 32'bx);
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid     = e[i].valid;
		assign e_updated[i].tag       = e[i].tag;
		assign e_updated[i].is_fneg   = e[i].is_fneg;
		assign e_updated[i].is_fabs   = e[i].is_fabs;
		assign e_updated[i].opd.valid = e[i].opd.valid || tag_match(fpr_cdb, e[i].opd.tag);
		assign e_updated[i].opd.tag   = e[i].opd.tag;
		assign e_updated[i].opd.data  = e[i].opd.valid ? e[i].opd.data : modify_sign(e[i].is_fneg, e[i].is_fabs, fpr_cdb.data);
	end

	logic dispatchable[2:0];
	assign dispatchable[0] = e_updated[0].valid&&e_updated[0].opd.valid;
	assign dispatchable[1] = e_updated[1].valid&&e_updated[1].opd.valid;
	assign dispatchable[2] = e_new       .valid&&e_new       .opd.valid;
	assign fpr_cdb_req.valid = dispatchable[0] || dispatchable[1] || dispatchable[2];
	assign tag = dispatchable[0] ? e_updated[0].tag :
	             dispatchable[1] ? e_updated[1].tag : e_new.tag;
	wire dispatch = fpr_cdb_req.valid && fpr_cdb_req.ready;
	assign issue_req.ready = dispatch || !e[N_ENTRY-1].valid;

	always_ff @(posedge clk) begin
		if (reset) begin
			e[0] <= e_invalid;
			e[1] <= e_invalid;
		end else begin
			if (dispatch) begin
				e[0] <= dispatchable[0] ? e[1].valid ? e_updated[1] : e_new : e_updated[0];
				e[1] <= e[1].valid&&(dispatchable[0]||dispatchable[1]) ? e_new : e_invalid;
			end else begin
				e[0] <= e[0].valid ? e_updated[0] : e_new;
				e[1] <= e[1].valid ? e_updated[1] : e[0].valid ? e_new : e_invalid;
			end
		end
		result <= dispatchable[0] ? e_updated[0].opd.data :
		          dispatchable[1] ? e_updated[1].opd.data : e_new.opd.data;
	end
endmodule
