`include "common.vh"

module commit_ring #(
) (
	input logic clk,
	req_if issue_req,
	commit_ring_entry issue_type,
	req_if commit_req_gpr,
	//req_if commit_req_fpr,
	//req_if commit_req_sw,
	req_if commit_req_out,
	//req_if commit_req_b,
	input logic reset
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
	wire issue = issue_req.valid && issue_req.ready;
	wire commit = commit_req_gpr.valid && commit_req_gpr.ready ||
	              commit_req_out.valid && commit_req_out.ready;
	always_ff @(posedge clk) begin
		if (reset) begin
			issue_pointer <= 0;
			commit_pointer <= 0;
		end else begin
			if (issue) begin
				issue_pointer <= issue_pointer + 1;
			end
			if (commit) begin
				commit_pointer <= commit_pointer + 1;
			end
		end
	end
	for (genvar i=0; i<2**COMMIT_RING_ENTRY; i++) begin
		always_ff @(posedge clk) begin
			if (reset) begin
				entry[i] <= COMMIT_RESET;
			end else (issue && issue_pointer==i) begin
				entry[i] <= issue_type;
			end
		end
	end
endmodule
