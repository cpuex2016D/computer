`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	cdb_t opd;
} ftoi_entry;

module ftoi #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t fpr_read[1:0],
	input cdb_t fpr_cdb,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam ftoi_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}
	};
	ftoi_entry e[N_ENTRY-1:0];  //0から順に詰める
	ftoi_entry e_updated[N_ENTRY-1:0];
	ftoi_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid     = issue_req.valid;
	assign e_new.tag       = gpr_issue_tag;
	assign e_new.opd.valid = fpr_read[0].valid ? tag_match(fpr_cdb, e_new.opd.tag) ? 1'bx : 1
	                                           : tag_match(fpr_cdb, e_new.opd.tag) ?    1 : 0;
	assign e_new.opd.tag   = fpr_read[0].tag;
	assign e_new.opd.data  = fpr_read[0].valid ? tag_match(fpr_cdb, e_new.opd.tag) ? 32'bx        : fpr_read[0].data
	                                           : tag_match(fpr_cdb, e_new.opd.tag) ? fpr_cdb.data : 32'bx;
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid     = e[i].valid;
		assign e_updated[i].tag       = e[i].tag;
		assign e_updated[i].opd.valid = e[i].opd.valid || tag_match(fpr_cdb, e[i].opd.tag);
		assign e_updated[i].opd.tag   = e[i].opd.tag;
		assign e_updated[i].opd.data  = e[i].opd.valid ? e[i].opd.data : fpr_cdb.data;
	end

	wire dispatched = e[0].opd.valid ? 0 : 1;  //dispatchされるエントリの番号
	assign gpr_cdb_req.valid = e[0].valid&&e[0].opd.valid ||
	                           e[1].valid&&e[1].opd.valid;
	assign tag = e[dispatched].tag;
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
	end
	ftoi_core ftoi_core(
		.s_axis_a_tdata(e[dispatched].opd.data),
		.m_axis_result_tdata(result)
	);
endmodule
