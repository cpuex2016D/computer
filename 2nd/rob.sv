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
	output logic[31:0] commit_data
);
	rob_entry rob[2**ROB_WIDTH-1:0];
	logic[ROB_WIDTH-1:0] issue_pointer = 0;
	logic[ROB_WIDTH-1:0] commit_pointer = 0;

	for (genvar i=0; i<2; i++) begin
		assign read[i] = rob[read_tag[i]];
	end
	assign issue_tag = issue_pointer;
	assign commit_tag = commit_pointer;
	assign commit_data = rob[commit_pointer].data;
	assign commit_req.ready = rob[commit_pointer].valid;

	always_ff @(posedge clk) begin
		if (issue) begin
			issue_pointer <= issue_pointer + 1;
		end

//		if (cdb.valid && commit_req.valid && commit_req.ready && cdb.tag==commit_pointer) begin  //ありえない
//			rob[cdb.tag].valid <= 1'bx;
//		end else begin
			if (cdb.valid) begin
				rob[cdb.tag].valid <= 1;
				rob[cdb.tag].data <= cdb.data;
			end
			if (commit_req.valid && commit_req.ready) begin
				rob[commit_pointer].valid <= 0;
				commit_pointer <= commit_pointer + 1;
			end
//		end
	end
endmodule
