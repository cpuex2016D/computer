module receiver_wrapper #(
	parameter WIDTH = 12
) (
	input logic CLK,
	input logic in,
	input logic ready,
	output logic[7:0] out,
	output logic valid
);
	logic[7:0] receiver_out;
	logic receiver_valid;
	receiver receiver(CLK, in, receiver_out, receiver_valid);
	(* ram_style = "distributed" *) logic[7:0] buffer[2**WIDTH-1:0];
	logic[WIDTH-1:0] in_pointer = 0;
	logic[WIDTH-1:0] out_pointer = 0;

	assign valid = in_pointer!=out_pointer;
	assign out = buffer[out_pointer];

	always_ff @(posedge CLK) begin
		if (receiver_valid) begin
			buffer[in_pointer] <= receiver_out;
			in_pointer <= in_pointer + 1;
		end
		if (valid && ready) begin
			out_pointer <= out_pointer + 1;
		end
	end
endmodule
