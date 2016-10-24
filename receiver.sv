module receiver #(
	//parameter COUNT_WIDTH = 11,
	//parameter COUNT_MAX = 11'd1301  // 300000000/115200/2 = 1302.0833333333333
	parameter COUNT_WIDTH = 10,
	parameter COUNT_MAX = 10'd537  // 125000000/115200/2 = 542.5347222222222
) (
	input logic CLK,
	input logic in,
	output logic[7:0] out,
	output logic valid
);
	logic[COUNT_WIDTH-1:0] count_half_period = 0;
	logic receiving = 1'b0;
	logic[3:0] state = 4'b0000;  /* 0001->0010->receiving->0100->1000 */

	always_comb begin
		if (receiving && state == 4'b1111 && count_half_period == 0) begin
			valid <= 1;
		end else begin
			valid <= 0;
		end
	end

	always @(posedge CLK) begin
		if (!{receiving, state} && !in) begin
			state <= 4'b0001;
		end

		if (count_half_period == COUNT_MAX) begin
			count_half_period <= 0;
			if (receiving) begin
				if (state == 4'b1111) begin
					receiving <= 0;
					state <= 4'b0100;
				end else begin
					state <= state + 1;
					if (!state[0]) begin
						out[state[3:1]] <= in;
					end
				end
			end else begin
				if (state[1]) begin
					receiving <= 1;
					state <= 4'b0000;
				end else if (state[3]) begin
					state <= 4'b0000;
				end else begin
					state[0] <= state[3];
					state[1] <= state[0];
					state[2] <= state[1];
					state[3] <= state[2];
				end
			end
		end else begin
			if ({receiving, state}) begin
				count_half_period <= count_half_period + 1;
			end
		end
	end
endmodule
