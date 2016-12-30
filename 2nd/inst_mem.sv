`include "common.vh"

module inst_mem #(
) (
	input logic clk,
	input logic[INST_WIDTH-1:0] inst_in,
	input logic we,
	input logic reset_pc,
	input logic stall,
	output logic[INST_MEM_WIDTH-1:0] pc = 0,
	inst_if inst
);
	(* ram_style = "distributed" *) logic[INST_WIDTH-1:0] inst_mem[2**INST_MEM_WIDTH-1:0];
	wire[INST_WIDTH-1:0] inst_j  = inst_mem[inst.c_j];
	wire[INST_WIDTH-1:0] inst_pc = inst_mem[pc];

	always_ff @(posedge clk) begin
		if (reset_pc) begin
			pc <= 0;
		end else if (!stall) begin
			if (inst.is_j) begin
				pc <= inst.c_j + 1;
			end else begin
				pc <= pc + 1;
			end
		end

		if (we) begin
			inst_mem[pc] <= inst_in;
		end

		if (!stall) begin
			if (inst.is_j) begin
				inst.bits <= inst_j;
			end else begin
				inst.bits <= inst_pc;
			end
		end
	end
endmodule
