`include "common.vh"

module in #(
) (
	input logic clk,
	inst_if inst,
	req_if issue_req,
	req_if gpr_cdb_req,
	req_if fpr_cdb_req,
	output logic[31:0] result,
	input logic[31:0] receiver_out,
	input logic receiver_valid,
	output logic receiver_ready,
	input logic speculating
);
	assign gpr_cdb_req.valid = issue_req.valid && inst.op[0]==0 && receiver_valid && !speculating;
	assign fpr_cdb_req.valid = issue_req.valid && inst.op[0]==1 && receiver_valid && !speculating;
	assign result = receiver_out;
	assign issue_req.ready = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                         fpr_cdb_req.valid && fpr_cdb_req.ready;
	assign receiver_ready  = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                         fpr_cdb_req.valid && fpr_cdb_req.ready;
endmodule
