`include "common.vh"

typedef enum logic {FDIV, FSQRT, X_FDIV_FSQRT=1'bx} fdiv_or_fsqrt_t;
typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	fdiv_or_fsqrt_t fdiv_or_fsqrt;
	cdb_t opd[1:0];
} fdiv_fsqrt_entry;

module fdiv_fsqrt #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t fpr_read[1:0],
	input cdb_t fpr_cdb,
	input logic[ROB_WIDTH-1:0] fpr_issue_tag,
	req_if issue_req,
	req_if fpr_cdb_req,
	output logic fpr_cdb_req_is_fsqrt,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result_fdiv,
	output logic[31:0] result_fsqrt,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam fdiv_fsqrt_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		fdiv_or_fsqrt: X_FDIV_FSQRT,
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
	fdiv_fsqrt_entry e[N_ENTRY-1:0];  //0から順に詰める
	fdiv_fsqrt_entry e_updated[N_ENTRY-1:0];
	fdiv_fsqrt_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid         = issue_req.valid;
	assign e_new.tag           = fpr_issue_tag;
	assign e_new.fdiv_or_fsqrt = inst.op[2] ? FSQRT : FDIV;
	assign e_new.opd[0].valid  = fpr_read[0].valid ? tag_match(fpr_cdb, e_new.opd[0].tag) ? 1'bx : 1
	                                               : tag_match(fpr_cdb, e_new.opd[0].tag) ?    1 : 0;
	assign e_new.opd[1].valid  = e_new.fdiv_or_fsqrt==FSQRT ||
	                             (fpr_read[1].valid ? tag_match(fpr_cdb, e_new.opd[1].tag) ? 1'bx : 1
	                                                : tag_match(fpr_cdb, e_new.opd[1].tag) ?    1 : 0);
	for (genvar j=0; j<2; j++) begin
		assign e_new.opd[j].tag  = fpr_read[j].tag;
		assign e_new.opd[j].data = fpr_read[j].valid ? tag_match(fpr_cdb, e_new.opd[j].tag) ? 32'bx        : fpr_read[j].data
		                                             : tag_match(fpr_cdb, e_new.opd[j].tag) ? fpr_cdb.data : 32'bx;
	end
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid         = e[i].valid;
		assign e_updated[i].tag           = e[i].tag;
		assign e_updated[i].fdiv_or_fsqrt = e[i].fdiv_or_fsqrt;
		for (genvar j=0; j<2; j++) begin
			assign e_updated[i].opd[j].valid = e[i].opd[j].valid || tag_match(fpr_cdb, e[i].opd[j].tag);
			assign e_updated[i].opd[j].tag   = e[i].opd[j].tag;
			assign e_updated[i].opd[j].data  = e[i].opd[j].valid ? e[i].opd[j].data : fpr_cdb.data;
		end
	end

	wire dispatched = e[0].opd[0].valid&&e[0].opd[1].valid ? 0 : 1;  //dispatchされるエントリの番号
	assign fpr_cdb_req.valid = e[0].valid&&e[0].opd[0].valid&&e[0].opd[1].valid ||
	                           e[1].valid&&e[1].opd[0].valid&&e[1].opd[1].valid;
	assign fpr_cdb_req_is_fsqrt = e[dispatched].fdiv_or_fsqrt==FSQRT;
	assign tag = e[dispatched].tag;
	wire dispatch = fpr_cdb_req.valid && fpr_cdb_req.ready;
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
	fdiv_core fdiv_core(
		.s_axis_a_tdata(e[dispatched].opd[0].data),
		.s_axis_b_tdata(e[dispatched].opd[1].data),
		.m_axis_result_tdata(result_fdiv)
	);
	fsqrt_core fsqrt_core(
		.s_axis_a_tdata(e[dispatched].opd[0].data),
		.m_axis_result_tdata(result_fsqrt)
	);
endmodule
