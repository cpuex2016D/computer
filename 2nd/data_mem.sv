`include "common.vh"

module data_mem #(
) (
	input logic clk,
	input logic[DATA_MEM_WIDTH-1:0] addra,
	input logic[31:0] dina,
	input logic wea,
	input logic[DATA_MEM_WIDTH-1:0] addrb,
	output logic[31:0] doutb
);
	logic[31:0] mem[2**DATA_MEM_WIDTH-1:0];

	always_ff @(posedge clk) begin
		if (wea) mem[addra] <= dina;
		doutb <= mem[addrb];
	end
endmodule
