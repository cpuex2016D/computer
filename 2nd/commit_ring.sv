`include "common.vh"

module commit_ring #(
) (
	input logic clk,
	req_if issue_req,
	commit_ring_entry issue_type,
	req_if commit_req_gpr,
	//req_if commit_req_fpr,
	//req_if commit_req_sw,
	req_if commit_req_out
	//req_if commit_req_b
);
	commit_ring_entry entry[2**COMMIT_RING_WIDTH-1:0];
	logic[COMMIT_RING_WIDTH-1:0] issue_pointer = 0;
	logic[COMMIT_RING_WIDTH-1:0] commit_pointer = 0;

	assign issue_req.ready = issue_pointer + 1 != commit_pointer;
	wire empty = issue_pointer == commit_pointer;
	assign commit_req_gpr.valid = !empty &&
	                              (entry[commit_pointer]==COMMIT_GPR ||
	                               entry[commit_pointer]==COMMIT_GPR_IN);
	assign commit_req_out.valid = !empty &&
	                              (entry[commit_pointer]==COMMIT_OUT);
	always_ff @(posedge clk) begin
		if (issue_req.valid && issue_req.ready) begin
			entry[issue_pointer] <= issue_type;
			issue_pointer <= issue_pointer + 1;
		end
		if (commit_req_gpr.valid && commit_req_gpr.ready ||
		    commit_req_out.valid && commit_req_out.ready) begin
			commit_pointer <= commit_pointer + 1;
		end
	end
endmodule
