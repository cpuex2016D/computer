`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic[$clog2(N_B_ENTRY):0] b_count;
} next_entry;

module next #(
) (
	input logic clk,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	input logic[$clog2(N_B_ENTRY):0] b_count_next,
	input logic b_commit,
	req_if issue_req,
	req_if gc_req,
	req_if gpr_cdb_req,
	input logic[GC_WIDTH-1:0] gc,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic failure,
	output logic next_e_exists
);
	localparam next_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		b_count: {$clog2(N_B_ENTRY)+1{1'bx}}
	};
	next_entry e = e_invalid;
	next_entry e_updated;
	next_entry e_new;
	wire confirmed         = e        .valid && e        .b_count==0;
	wire confirmed_updated = e_updated.valid && e_updated.b_count==0;
	wire confirmed_new     = e_new    .valid && e_new    .b_count==0;
	assign next_e_exists = e.valid;

	assign e_new.valid   = issue_req.valid;
	assign e_new.tag     = gpr_issue_tag;
	assign e_new.b_count = b_count_next;
	assign e_updated.valid   = e.valid;
	assign e_updated.tag     = e.tag;
	assign e_updated.b_count = e.b_count==0 ? 0 : e.b_count-b_commit;

	assign gc_req.valid = gpr_cdb_req.ready && !failure && (confirmed_updated || confirmed_new);
	wire dispatch = gc_req.valid && gc_req.ready;
	assign gpr_cdb_req.valid = dispatch;
	assign tag = e.valid ? e_updated.tag : e_new.tag;
	//assign issue_req.ready = dispatch || !e.valid;  //next命令が次々に来ることはおそらくない
	assign issue_req.ready = !e.valid;

	always_ff @(posedge clk) begin
		if (failure && !confirmed) begin
			e <= e_invalid;
		end else begin
			if (dispatch) begin
				//e <= e_new;
				e <= e_invalid;
			end else begin
				e <= e.valid ? e_updated : e_new;
			end
		end
	end
	assign result = $signed(gc);
endmodule
