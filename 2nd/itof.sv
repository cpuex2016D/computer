`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	cdb_t opd;
} itof_entry;

module itof #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t gpr_read[1:0],
	input cdb_t gpr_cdb,
	input logic[ROB_WIDTH-1:0] fpr_issue_tag,
	req_if issue_req,
	req_if fpr_cdb_req,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam itof_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}
	};
	itof_entry e[N_ENTRY-1:0];  //0から順に詰める
	itof_entry e_updated[N_ENTRY-1:0];
	itof_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid     = issue_req.valid;
	assign e_new.tag       = fpr_issue_tag;
	assign e_new.opd.valid = gpr_read[0].valid;
	assign e_new.opd.tag   = gpr_read[0].tag;
	assign e_new.opd.data  = gpr_read[0].data;
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid     = e[i].valid;
		assign e_updated[i].tag       = e[i].tag;
		assign e_updated[i].opd.valid = e[i].opd.valid || tag_match(gpr_cdb, e[i].opd.tag);
		assign e_updated[i].opd.tag   = e[i].opd.tag;
		assign e_updated[i].opd.data  = e[i].opd.valid ? e[i].opd.data : gpr_cdb.data;
	end

	wire dispatched = e[0].opd.valid ? 0 : 1;  //dispatchされるエントリの番号
	assign fpr_cdb_req.valid = e[0].valid&&e[0].opd.valid ||
	                           e[1].valid&&e[1].opd.valid;
	itof_entry e_dispatched;
	assign e_dispatched = e[dispatched];
	assign tag = e_dispatched.tag;
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
	itof_core itof_core(
		.aclk(clk),
		.s_axis_a_tdata(e[dispatched].opd.data),
		.m_axis_result_tdata(result)
	);
endmodule
