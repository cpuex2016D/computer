`include "common.vh"

module commit_ring #(
) (
	input logic clk,
	req_if issue_req,
	commit_ring_entry issue_type,
	req_if commit_req_gpr,
	req_if commit_req_fpr,
	req_if commit_req_sw,
	req_if commit_req_b,
	output logic empty,
	input logic reset,
	output logic[COMMIT_RING_WIDTH-1:0] in_count
);
	commit_ring_entry entry[2**COMMIT_RING_WIDTH] = '{default: COMMIT_NULL};
	logic[COMMIT_RING_WIDTH-1:0] issue_pointer = 0;
	logic[COMMIT_RING_WIDTH-1:0] commit_pointer = 0;

	assign issue_req.ready = COMMIT_RING_WIDTH'(issue_pointer+1) != commit_pointer;
	assign empty = issue_pointer==commit_pointer;
	assign commit_req_gpr.valid = entry[commit_pointer]==COMMIT_GPR ||
	                              entry[commit_pointer]==COMMIT_GPR_IN;
	assign commit_req_fpr.valid = entry[commit_pointer]==COMMIT_FPR ||
	                              entry[commit_pointer]==COMMIT_FPR_IN;
	assign commit_req_sw.valid  = entry[commit_pointer]==COMMIT_SW;
	assign commit_req_b.valid   = entry[commit_pointer]==COMMIT_B;
	wire issue = issue_req.valid && issue_req.ready;
	wire commit = commit_req_gpr.valid && commit_req_gpr.ready ||
	              commit_req_fpr.valid && commit_req_fpr.ready ||
	              commit_req_sw.valid  && commit_req_sw.ready  ||
	              commit_req_b.valid   && commit_req_b.ready;
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
	for (genvar i=0; i<2**COMMIT_RING_WIDTH; i++) begin
		always_ff @(posedge clk) begin
			case ({reset, commit&&commit_pointer==i, issue&&issue_pointer==i})
				3'b111: entry[i] <= COMMIT_X;
				3'b110: entry[i] <= COMMIT_NULL;
				3'b101: entry[i] <= COMMIT_NULL;
				3'b100: entry[i] <= COMMIT_NULL;
				3'b011: entry[i] <= COMMIT_X;
				3'b010: entry[i] <= COMMIT_NULL;
				3'b001: entry[i] <= issue_type;
			endcase
		end
	end
	assign in_count = (entry[ 0]==COMMIT_GPR_IN || entry[ 0]==COMMIT_FPR_IN) +
	                  (entry[ 1]==COMMIT_GPR_IN || entry[ 1]==COMMIT_FPR_IN) +
	                  (entry[ 2]==COMMIT_GPR_IN || entry[ 2]==COMMIT_FPR_IN) +
	                  (entry[ 3]==COMMIT_GPR_IN || entry[ 3]==COMMIT_FPR_IN) +
	                  (entry[ 4]==COMMIT_GPR_IN || entry[ 4]==COMMIT_FPR_IN) +
	                  (entry[ 5]==COMMIT_GPR_IN || entry[ 5]==COMMIT_FPR_IN) +
	                  (entry[ 6]==COMMIT_GPR_IN || entry[ 6]==COMMIT_FPR_IN) +
	                  (entry[ 7]==COMMIT_GPR_IN || entry[ 7]==COMMIT_FPR_IN) +
	                  (entry[ 8]==COMMIT_GPR_IN || entry[ 8]==COMMIT_FPR_IN) +
	                  (entry[ 9]==COMMIT_GPR_IN || entry[ 9]==COMMIT_FPR_IN) +
	                  (entry[10]==COMMIT_GPR_IN || entry[10]==COMMIT_FPR_IN) +
	                  (entry[11]==COMMIT_GPR_IN || entry[11]==COMMIT_FPR_IN) +
	                  (entry[12]==COMMIT_GPR_IN || entry[12]==COMMIT_FPR_IN) +
	                  (entry[13]==COMMIT_GPR_IN || entry[13]==COMMIT_FPR_IN) +
	                  (entry[14]==COMMIT_GPR_IN || entry[14]==COMMIT_FPR_IN) +
	                  (entry[15]==COMMIT_GPR_IN || entry[15]==COMMIT_FPR_IN);
endmodule
