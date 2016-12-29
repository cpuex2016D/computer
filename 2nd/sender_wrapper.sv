`include "common.vh"

module sender_wrapper #(
	parameter SENDER_PERIOD = "hoge"
) (
	input logic clk,
	input logic[7:0] in,
	input logic valid,
	output logic out,
	output logic ready
);
	logic[7:0] sender_in;
	logic sender_valid;
	logic sender_ready;
	sender #(SENDER_PERIOD) sender(
		.clk,
		.in(sender_in),
		.valid(sender_valid),
		.out,
		.ready(sender_ready)
	);
	(* ram_style = "distributed" *) logic[7:0] buffer[2**OUT_BUFFER_WIDTH-1:0];
	logic[OUT_BUFFER_WIDTH-1:0] in_pointer = 0;
	logic[OUT_BUFFER_WIDTH-1:0] out_pointer = 0;

	assign ready = in_pointer + 1 != out_pointer;
	assign sender_valid = in_pointer != out_pointer;
	assign sender_in = buffer[out_pointer];

	always_ff @(posedge clk) begin
		if (valid && ready) begin
			buffer[in_pointer] <= in;
			in_pointer <= in_pointer + 1;
		end
		if (sender_valid && sender_ready) begin
			out_pointer <= out_pointer + 1;
		end
	end
endmodule
