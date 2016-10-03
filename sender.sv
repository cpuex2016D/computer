module sender #(
	parameter COUNT_WIDTH = 12,
	parameter COUNT_MAX = 12'd2603  // 300000000/115200 = 2604.1666666666665
) (
	input logic CLK,
	input logic[7:0] in,
	input logic start_send,
	output logic out
);
	logic[7:0] buffer;
	logic[COUNT_WIDTH-1:0] count_period = 0;
	logic sending = 1'b0;
	logic[2:0] state = 3'b001;  /* 100->sending->101 */

	always_comb begin
		if (sending) begin
			out <= buffer[state];
		end else begin
			out <= state[0];
		end
	end

	always @(posedge CLK) begin
		if (!(sending || state[2]) && start_send) begin
			state <= 3'b100;
			buffer <= in;
		end

		if (count_period == COUNT_MAX) begin
			count_period <= 0;
			if (sending) begin
				if (state == 3'b111) begin
					sending <= 1'b0;
					state <= 3'b101;
				end else begin
					state <= state + 1;
				end
			end else begin
				if (state[0] == 1'b0) begin
					sending <= 1;
					state <= 3'b000;
				end else begin
					state[2] <= 1'b0;
				end
			end
		end else begin
			if (sending || state[2]) begin
				count_period <= count_period + 1;
			end
		end
	end
endmodule
