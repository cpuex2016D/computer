`include "common.vh"

module inst_mem #(
) (
	input logic clk,
	input logic[INST_WIDTH-1:0] inst_in,
	input logic we,
	input logic reset_pc,
	input logic stall,
	input mode_t mode,
	output logic[INST_MEM_WIDTH-1:0] pc = 0,
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
	(* ram_style = "distributed" *) logic[1:0] pht[2**PATTERN_WIDTH];
	logic[GH_WIDTH-1:0] gh = 0;
	initial begin
		inst.bits <= 0;
	end

	logic[INST_MEM_WIDTH-1:0] inst_addr;
	always_comb begin
		if (reset) begin
			inst_addr <= addr_on_failure;
		end else if (inst.is_j || inst.is_b && prediction_begin[1]) begin
			inst_addr <= inst.c_j;
		end else if (inst.is_jr) begin
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
		if (reset_pc) begin
			pc <= 0;
		end else if (reset) begin
			pc <= addr_on_failure + 1;
		end else if (!stall) begin
			if (mode==LOAD) begin
				pc <= pc + 1;
			end else if (inst.is_j || inst.is_b && prediction_begin[1]) begin
				pc <= inst.c_j + 1;
			end else if (inst.is_jr) begin
				pc <= return_addr + 1;
			end else begin
				pc <= pc + 1;
			end
		end

		if (we) begin
			inst_mem[pc] <= inst_in;
		end
		if (!(!reset && stall)) begin
			inst.bits <= inst_mem[inst_addr];
		end

		pattern_begin <= pattern;
		if (commit_b) begin
			gh <= {gh[GH_WIDTH-2:0], taken};
			pht[pattern_end] <= prediction_updated;
		end
		if (!(!reset && stall)) begin
			prediction_begin <= pht[pattern];
		end
	end
endmodule
