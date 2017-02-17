`include "common.vh"

module inst_mem #(
	parameter PARENT = "hoge"
) (
	input logic clk,
	input logic issue_fork,
	input logic stall,
	input logic parallel,
	output logic[INST_MEM_WIDTH-1:0] pc,
	inst_if inst,
	output logic[PATTERN_WIDTH-1:0] pattern_begin,
	input logic[PATTERN_WIDTH-1:0] pattern_end,
	output logic[1:0] prediction_begin,
	input logic[1:0] prediction_end,
	input logic failure,
	input logic commit_b,
	input logic reset,
	input logic[INST_MEM_WIDTH-1:0] addr_on_failure,
	input logic[INST_MEM_WIDTH-1:0] return_addr
);
	(* ram_style = "distributed" *) logic[INST_WIDTH-1:0] inst_mem[2**INST_MEM_WIDTH];
	(* ram_style = "distributed" *) logic[1:0] pht[2**PATTERN_WIDTH] = '{default: 0};
	logic[GH_WIDTH-1:0] gh = 0;
	initial begin
		$readmemh("../../../fork.text.hex", inst_mem);
		inst.bits <= PARENT ? {4'h8, 4'b0, PC_INIT[13:11], 10'b0, PC_INIT[10:0]} : 32'h7c000000;
	end

	logic[INST_MEM_WIDTH-1:0] inst_addr;
	always_comb begin
		if (reset) begin
			inst_addr <= addr_on_failure;
		end else if (inst.is_j || inst.is_b && prediction_begin[1] || issue_fork) begin
			inst_addr <= inst.c_j;
		end else if (inst.is_jr || inst.is_fork_end && parallel && PARENT) begin
			inst_addr <= return_addr;
		end else begin
			inst_addr <= pc;
		end
	end
	wire[PATTERN_WIDTH-1:0] pattern = inst_addr ^ {gh, {PATTERN_WIDTH-GH_WIDTH{1'b0}}};
	wire taken = prediction_end[1] ^ failure;
	logic[1:0] prediction_updated;
	assign prediction_updated[1] = prediction_end[1] ^ (!prediction_end[0] && failure);
	assign prediction_updated[0] = !failure;

	always_ff @(posedge clk) begin
		if (issue_fork || reset || !stall) begin
			pc <= inst_addr + 1;
		end

		if (issue_fork || reset || !stall) begin
			inst.bits <= inst_mem[inst_addr];
		end

		pattern_begin <= pattern;
		if (commit_b) begin
			gh <= {gh[GH_WIDTH-2:0], taken};
			pht[pattern_end] <= prediction_updated;
		end
		if (issue_fork || reset || !stall) begin
			prediction_begin <= pht[pattern];
		end
	end
endmodule
