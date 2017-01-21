`include "common.vh"

module in #(
) (
	input logic clk,
	inst_if inst,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	input logic[ROB_WIDTH-1:0] fpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	req_if fpr_cdb_req,
	output cdb_t result_in,
	output cdb_t result_fin,
	input logic[31:0] receiver_out,
	input logic receiver_valid,
	output logic receiver_ready
);
	assign gpr_cdb_req.valid = issue_req.valid && inst.op[0]==0 && receiver_valid;
	assign fpr_cdb_req.valid = issue_req.valid && inst.op[0]==1 && receiver_valid;
	assign result_in.tag   = gpr_issue_tag;
	assign result_in.data  = receiver_out;
	assign result_fin.tag  = fpr_issue_tag;
	assign result_fin.data = receiver_out;
	assign issue_req.ready = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                         fpr_cdb_req.valid && fpr_cdb_req.ready;
	assign receiver_ready  = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                         fpr_cdb_req.valid && fpr_cdb_req.ready;
endmodule
