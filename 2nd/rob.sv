`include "common.vh"

module rob #(
) (
	input logic clk,
	input logic[ROB_WIDTH-1:0] read_tag[1:0],
	output rob_entry read[1:0],
	input cdb_t cdb,
	input logic issue,
	output logic[ROB_WIDTH-1:0] issue_tag,
	req_if commit_req,
	output logic[ROB_WIDTH-1:0] commit_tag,
	output logic[31:0] commit_data,
	input logic reset
);
	rob_entry rob[2**ROB_WIDTH-1:0];
	logic[ROB_WIDTH-1:0] issue_pointer = 0;
	logic[ROB_WIDTH-1:0] commit_pointer = 0;

	for (genvar i=0; i<2; i++) begin
		assign read[i] = rob[read_tag[i]];
	end
	assign issue_tag = issue_pointer;
	assign commit_tag = commit_pointer;
	rob_entry commit_e;
	assign commit_e = rob[commit_pointer];
	assign commit_data = commit_e.data;
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

		if (cdb.valid) begin
			rob[cdb.tag].valid <= 1;
			rob[cdb.tag].data <= cdb.data;
		end
		if (issue && !(cdb.valid && cdb.tag==issue_pointer)) begin
			rob[issue_pointer].valid <= 0;
		end
	end
endmodule
