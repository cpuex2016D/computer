`include "common.vh"

module data_mem_parent #(
) (
	input logic clk,
	input logic[DATA_MEM_WIDTH-1:0] addra,
	input logic[DATA_MEM_WIDTH-1:0] addrb,
	input logic[31:0] dina,
	output logic[31:0] doutb,
	input logic wea
);
	(* ram_style = "distributed" *) logic[31:0] data_mem[DATA_MEM_DEPTH];
	initial begin
		$readmemh("data.hex", data_mem);
	end

	always @(posedge clk) begin
		if (wea) begin
			data_mem[addra] <= dina;
		end
	end
	assign doutb = data_mem[addrb];
endmodule
