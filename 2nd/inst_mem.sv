`include "common.vh"

module inst_mem #(
) (
	input logic clk,
	input logic[INST_WIDTH-1:0] inst_in,
	input logic we,
	input logic reset_pc,
	input logic stall,
	output logic[INST_MEM_WIDTH-1:0] pc = 0,
	inst_if inst,
	input prediction,
	input logic reset,
	input logic[INST_MEM_WIDTH-1:0] addr_on_failure,
	input logic[INST_MEM_WIDTH-1:0] return_addr
);
	(* ram_style = "distributed" *) logic[INST_WIDTH-1:0] inst_mem[2**INST_MEM_WIDTH-1:0];

	always_ff @(posedge clk) begin
		if (reset_pc) begin
			pc <= 0;
		end else if (reset) begin
			pc <= addr_on_failure + 1;
		end else if (!stall) begin
			if (inst.is_j || inst.is_b && prediction) begin
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

		if (reset) begin
			inst.bits <= inst_mem[addr_on_failure];
		end else if (!stall) begin
			if (inst.is_j || inst.is_b && prediction) begin
				inst.bits <= inst_mem[inst.c_j];
			end else if (inst.is_jr) begin
				inst.bits <= inst_mem[return_addr];
			end else begin
				inst.bits <= inst_mem[pc];
			end
		end
	end
endmodule
