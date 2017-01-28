`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic is_fsub;
	cdb_t opd[1:0];
} fadd_fsub_entry;

module fadd_fsub #(
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
	localparam fadd_fsub_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		is_fsub: 1'bx,
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
	fadd_fsub_entry e[N_ENTRY-1:0];  //0から順に詰める
	fadd_fsub_entry e_updated[N_ENTRY-1:0];
	fadd_fsub_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid   = issue_req.valid;
	assign e_new.tag     = fpr_issue_tag;
	assign e_new.is_fsub = inst.op[0];
	for (genvar j=0; j<2; j++) begin
		assign e_new.opd[j].valid = fpr_read[j].valid;
		assign e_new.opd[j].tag   = fpr_read[j].tag;
		assign e_new.opd[j].data  = fpr_read[j].data;
	end
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid   = e[i].valid;
		assign e_updated[i].tag     = e[i].tag;
		assign e_updated[i].is_fsub = e[i].is_fsub;
		for (genvar j=0; j<2; j++) begin
			assign e_updated[i].opd[j].valid = e[i].opd[j].valid || tag_match(fpr_cdb, e[i].opd[j].tag);
			assign e_updated[i].opd[j].tag   = e[i].opd[j].tag;
			assign e_updated[i].opd[j].data  = e[i].opd[j].valid ? e[i].opd[j].data : fpr_cdb.data;
		end
	end

	wire dispatched = e[0].opd[0].valid&&e[0].opd[1].valid ? 0 : 1;  //dispatchされるエントリの番号
	assign fpr_cdb_req.valid = e[0].valid&&e[0].opd[0].valid&&e[0].opd[1].valid ||
	                           e[1].valid&&e[1].opd[0].valid&&e[1].opd[1].valid;
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
	fadd_fsub_core fadd_fsub_core(
		.aclk(clk),
		.s_axis_a_tdata(e[dispatched].opd[0].data),
		.s_axis_b_tdata(e[dispatched].opd[1].data),
		.s_axis_operation_tdata({7'b0, e[dispatched].is_fsub}),
		.m_axis_result_tdata(result)
	);
endmodule
