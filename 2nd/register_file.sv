`include "common.vh"

module register_file #(
) (
	input logic clk,
	inst_if inst,
	output cdb_t read[1:0],
	input logic issue,
	input logic[ROB_WIDTH-1:0] issue_tag,
	input logic commit,
	input logic[ROB_WIDTH-1:0] commit_tag,
	input logic[31:0] commit_data
);
	cdb_t registers[2**REG_WIDTH-1:0];

	assign read[0] = registers[inst.r1];
	assign read[1] = registers[inst.r2];

	always_ff @(posedge clk) begin
		if (issue) begin
			registers[inst.r0].valid <= 0;
			registers[inst.r0].tag <= issue_tag;
		end
	end
	for (genvar i=0; i<2**REG_WIDTH; i++) begin
		always_ff @(posedge clk) begin
			if (commit) begin
				if (!registers[i].valid && registers[i].tag==commit_tag) begin
					if (!(issue && i==inst.r0)) begin
						registers[i].valid <= 1;
					end
					registers[i].data <= commit_data;
				end
			end
		end
	end
endmodule
