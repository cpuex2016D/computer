`include "common.vh"

module in #(
) (
	input logic clk,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	output cdb_t result,
	input logic[31:0] receiver_out,
	input logic receiver_valid,
	output logic receiver_ready
);
	assign gpr_cdb_req.valid = issue_req.valid && receiver_valid;
	assign result.tag = gpr_issue_tag;
	assign result.data = receiver_out;
	assign issue_req.ready = gpr_cdb_req.valid && gpr_cdb_req.ready;
	assign receiver_ready  = gpr_cdb_req.valid && gpr_cdb_req.ready;
endmodule
