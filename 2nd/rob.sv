`include "common.vh"

module rob #(
) (
	input logic clk,
	input cdb_t arch_read[2],
	output rob_entry rob_read[2],
	input cdb_t cdb,
	input logic issue,
	inst_if inst,
	output logic[ROB_WIDTH-1:0] issue_tag,
	req_if commit_req,
	output logic[REG_WIDTH-1:0] commit_arch_num,
	output logic[ROB_WIDTH-1:0] commit_tag,
	output logic[31:0] commit_data,
	input logic reset
);
	rob_entry rob[2**ROB_WIDTH];
	logic[ROB_WIDTH-1:0] issue_pointer = 0;
	logic[ROB_WIDTH-1:0] commit_pointer = 0;

	for (genvar i=0; i<2; i++) begin
		assign rob_read[i] = rob[arch_read[i].tag];
	end
	assign issue_tag = issue_pointer;
	assign commit_tag = commit_pointer;
	rob_entry commit_e;
	assign commit_e = rob[commit_pointer];
	assign commit_data = commit_e.data;
	assign commit_arch_num = commit_e.arch_num;
	assign commit_req.ready = commit_e.valid;
	wire commit = commit_req.valid && commit_req.ready;

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
	for (genvar i=0; i<2**ROB_WIDTH; i++) begin
		always_ff @(posedge clk) begin
			if (tag_match(cdb, i)) begin
				rob[i].valid <= 1;
				rob[i].data <= cdb.data;
			end else if (issue && i==issue_pointer) begin  //in命令ではissueと同時にcdbにデータが流れる
				rob[i].valid <= 0;
			end
			if (issue && i==issue_pointer) begin
				rob[i].arch_num <= inst.r0;
			end
		end
	end
endmodule
