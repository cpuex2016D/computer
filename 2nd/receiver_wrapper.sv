`include "common.vh"

module receiver_wrapper #(
	parameter RECEIVER_PERIOD = "hoge"
) (
	input logic clk,
	input logic in,
	input logic ready,
	output logic[31:0] out,
	output logic valid,
	input logic reset,
	input logic[COMMIT_RING_WIDTH-1:0] in_count
);
	logic[7:0] receiver_out;
	logic receiver_valid;
	receiver #(RECEIVER_PERIOD) receiver(
		.clk,
		.in,
		.out(receiver_out),
		.valid(receiver_valid)
	);
	(* ram_style = "distributed" *) logic[31:0] buffer[2**IN_BUFFER_WIDTH];
	logic[IN_BUFFER_WIDTH-1:0] in_pointer = 0;
	logic[IN_BUFFER_WIDTH-1:0] out_pointer = 0;
	logic[1:0] in_pointer_sub = 0;

	assign valid = in_pointer!=out_pointer;
	assign out = buffer[out_pointer];

	always_ff @(posedge clk) begin
		if (receiver_valid) begin
			buffer[in_pointer][in_pointer_sub*8+:8] <= receiver_out;
			{in_pointer, in_pointer_sub} <= {in_pointer, in_pointer_sub} + 1;
		end
		if (reset) begin
			out_pointer <= out_pointer - in_count;
		end else if (valid && ready) begin
			out_pointer <= out_pointer + 1;
		end
	end
endmodule
