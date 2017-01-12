`include "common.vh"

module register_file #(
) (
	input logic clk,
	inst_if inst,
	output cdb_t read[1:0],
	input logic issue,
	input logic[ROB_WIDTH-1:0] issue_tag,
	input logic commit,
	input logic[ROB_WIDTH-1:0] commit_arch_num,
	input logic[ROB_WIDTH-1:0] commit_tag,
	input logic[31:0] commit_data,
	input logic reset
);
	cdb_t registers[2**REG_WIDTH-1:0] = '{default: '{
		valid: 1,
		tag: {ROB_WIDTH{1'bx}},
		data: 0
	}};

	assign read[0] = registers[inst.r1];
	assign read[1] = registers[inst.r2];

	for (genvar i=0; i<2**REG_WIDTH; i++) begin
		always_ff @(posedge clk) begin
			if (reset) begin
				registers[i].valid <= 1;
			end else if (issue && i==inst.r0) begin
				registers[i].valid <= 0;
			end else if (commit && /* !registers[i].valid && */ registers[i].tag==commit_tag) begin
				registers[i].valid <= 1;
			end

			if (issue && i==inst.r0) begin
				registers[i].tag <= issue_tag;
			end

			if (commit && !registers[i].valid && i==commit_arch_num) begin
				registers[i].data <= commit_data;
			end
		end
	end
endmodule
