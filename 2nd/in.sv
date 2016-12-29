`include "common.vh"

module in #(
) (
	input logic clk,
	input logic[ROB_WIDTH-1:0] issue_tag,
	req_if issue_req,
	req_if cdb_req,
	output cdb_t result,
	input logic[31:0] receiver_out,
	input logic receiver_valid,
	output logic receiver_ready
);
	assign cdb_req.valid = issue_req.valid && receiver_valid;
	assign result.tag = issue_tag;
	assign result.data = receiver_out;
	assign issue_req.ready = cdb_req.valid && cdb_req.ready;
	assign receiver_ready  = cdb_req.valid && cdb_req.ready;
endmodule
