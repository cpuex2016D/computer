`include "common.vh"

module data_mem #(
) (
	input logic clka,
	input logic clkb,
	input logic[DATA_MEM_WIDTH-1:0] addra,
	input logic[DATA_MEM_WIDTH-1:0] addrb,
	input logic[31:0] dina,
	output logic[31:0] doutb,
	input logic wea
);
	logic[31:0] data_mem[2**DATA_MEM_WIDTH];
	initial begin
		$readmemh("../../../fork.data.hex", data_mem);
	end

	always @(posedge clka) begin
		if (wea) begin
			data_mem[addra] <= dina;
		end
	end
	always @(posedge clkb) begin
		if (wea && addra==addrb) begin
			doutb <= dina;
		end else begin
			doutb <= data_mem[addrb];
		end
	end
endmodule
