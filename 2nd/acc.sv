`include "common.vh"

typedef struct {
	logic valid;
	cdb_t opd;
	logic[$clog2(N_B_ENTRY):0] b_count;
} acc_entry;

module acc #(
) (
	input logic clk,
	input cdb_t fpr_read[2],
	input cdb_t fpr_cdb,
	input logic[$clog2(N_B_ENTRY):0] b_count_next,
	input logic b_commit,
	req_if issue_req,
	req_if acc_req,
	output logic[31:0] acc_data,
	input logic failure
);
	localparam acc_entry e_invalid = '{
		valid: 0,
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		},
		b_count: {$clog2(N_B_ENTRY)+1{1'bx}}
	};
	acc_entry e = e_invalid;
	acc_entry e_updated;
	acc_entry e_new;
	wire confirmed = e.valid && e.b_count==0;

	assign e_new.valid     = issue_req.valid;
	assign e_new.opd.valid = fpr_read[0].valid;
	assign e_new.opd.tag   = fpr_read[0].tag;
	assign e_new.opd.data  = fpr_read[0].data;
	assign e_new.b_count   = b_count_next;
	assign e_updated.valid     = e.valid;
	assign e_updated.opd.valid = e.opd.valid || tag_match(fpr_cdb, e.opd.tag);
	assign e_updated.opd.tag   = e.opd.tag;
	assign e_updated.opd.data  = e.opd.valid ? e.opd.data : fpr_cdb.data;
	assign e_updated.b_count   = e.b_count==0 ? 0 : e.b_count-b_commit;

	assign acc_req.valid = e.valid&&e.b_count==0&&e.opd.valid;
	assign acc_data = e.opd.data;
	wire dispatch = acc_req.valid && acc_req.ready;
	assign issue_req.ready = dispatch || !e.valid;

	always_ff @(posedge clk) begin
		if (failure && !confirmed) begin
			e <= e_invalid;
		end else begin
			if (dispatch) begin
				e <= e_new;
			end else begin
				e <= e.valid ? e_updated : e_new;
			end
		end
	end
endmodule
